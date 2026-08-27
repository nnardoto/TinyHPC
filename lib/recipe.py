#!/usr/bin/env python3
"""Declarative, hierarchical package recipes for TinyHPC."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import urllib.request

try:
    import tomllib
except ModuleNotFoundError:  # Python 3.10 and older
    from _vendor import tomli as tomllib


SCHEMA_VERSION = 1
BUILD_SYSTEMS = {"autotools", "cmake", "make", "script"}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
CONFIG_ENVIRONMENT = (
    "TINYHPC_HOME",
    "TINYHPC_ROOT",
    "HPC_JOBS",
    "HPC_PROFILE",
    "HPC_OPT_FLAGS",
    "HPC_OPENBLAS_DYNAMIC_ARCH",
    "HPC_ROOT",
    "HPC_CACHE",
    "HPC_SRC",
    "HPC_BUILD",
    "HPC_SOFTWARE",
    "HPC_MODULEFILES",
    "HPC_LOGS",
)


class RecipeError(RuntimeError):
    pass


def die(message: str) -> None:
    raise RecipeError(message)


def note(message: str) -> None:
    print(f"==> {message}", flush=True)


def as_list(value: object, field: str) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list) and all(isinstance(item, str) for item in value):
        return list(value)
    die(f"{field} deve ser uma string ou uma lista de strings")


def lua_quote(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def fish_quote(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def render_environment(shell: str) -> None:
    for key in CONFIG_ENVIRONMENT:
        value = os.environ[key]
        if shell == "tsv":
            print(f"{key}\t{value}")
        elif shell in {"bash", "zsh"}:
            print(f"export {key}={shlex.quote(value)}")
        elif shell == "fish":
            print(f"set -gx {key} {fish_quote(value)};")


def read_configuration(path: Path, required: bool = False) -> dict[str, object]:
    if not path.is_file():
        if required:
            die(f"configuração não encontrada: {path}")
        return {}
    with path.open("rb") as handle:
        data = tomllib.load(handle)
    if data.get("schema") != SCHEMA_VERSION:
        die(f"{path}: schema deve ser {SCHEMA_VERSION}")
    paths = data.get("paths", {})
    build = data.get("build", {})
    if not isinstance(paths, dict) or not isinstance(build, dict):
        die(f"{path}: paths e build devem ser tabelas TOML")
    unknown_root = set(data) - {"schema", "paths", "build"}
    unknown_paths = set(paths) - {"home", "root"}
    unknown_build = set(build) - {"jobs", "profile"}
    if unknown_root or unknown_paths or unknown_build:
        unknown = sorted(unknown_root | unknown_paths | unknown_build)[0]
        die(f"{path}: campo de configuração desconhecido: {unknown}")
    for field, value in paths.items():
        if not isinstance(value, str) or not value:
            die(f"{path}: paths.{field} deve ser uma string não vazia")
    if "jobs" in build and (not isinstance(build["jobs"], int) or build["jobs"] < 1):
        die(f"{path}: build.jobs deve ser um inteiro positivo")
    if "profile" in build and (
        not isinstance(build["profile"], str)
        or build["profile"] not in {"generic", "native"}
    ):
        die(f"{path}: build.profile deve ser 'generic' ou 'native'")
    return data


def apply_configuration(repository_root: Path) -> Path | None:
    defaults_path = repository_root / "config" / "defaults.toml"
    defaults = read_configuration(defaults_path, required=True)

    configured_path = os.environ.get("TINYHPC_CONFIG")
    if configured_path:
        user_path = Path(os.path.expandvars(configured_path)).expanduser()
        user = read_configuration(user_path, required=True)
    else:
        config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
        user_path = config_home / "tinyhpc" / "config.toml"
        user = read_configuration(user_path)

    paths = dict(defaults.get("paths", {}))
    paths.update(user.get("paths", {}))
    build = dict(defaults.get("build", {}))
    build.update(user.get("build", {}))
    for required in ("home", "root"):
        if required not in paths:
            die(f"{defaults_path}: paths.{required} ausente")
    for required in ("jobs", "profile"):
        if required not in build:
            die(f"{defaults_path}: build.{required} ausente")

    os.environ.setdefault("TINYHPC_HOME", str(paths["home"]))
    os.environ.setdefault("TINYHPC_ROOT", str(paths["root"]))
    os.environ["TINYHPC_HOME"] = os.path.expandvars(os.path.expanduser(os.environ["TINYHPC_HOME"]))
    os.environ["TINYHPC_ROOT"] = os.path.expandvars(os.path.expanduser(os.environ["TINYHPC_ROOT"]))
    os.environ.setdefault("HPC_JOBS", str(build["jobs"]))
    os.environ.setdefault("HPC_PROFILE", str(build["profile"]))
    profile = os.environ["HPC_PROFILE"]
    if profile not in {"generic", "native"}:
        die("HPC_PROFILE deve ser 'generic' ou 'native'")
    if profile == "generic":
        optimization_flags = "-O3"
        openblas_dynamic_arch = "1"
    else:
        optimization_flags = "-O3 -march=native -mtune=native"
        openblas_dynamic_arch = "0"
    os.environ["HPC_OPT_FLAGS"] = optimization_flags
    os.environ["HPC_OPENBLAS_DYNAMIC_ARCH"] = openblas_dynamic_arch
    root = os.environ["TINYHPC_ROOT"]
    os.environ["HPC_ROOT"] = root
    os.environ["HPC_CACHE"] = f"{root}/cache"
    os.environ["HPC_SRC"] = f"{root}/src"
    os.environ["HPC_BUILD"] = f"{root}/build"
    os.environ["HPC_SOFTWARE"] = f"{root}/software"
    os.environ["HPC_MODULEFILES"] = f"{root}/modulefiles"
    os.environ["HPC_LOGS"] = f"{root}/logs"
    return user_path if user else None


class Recipe:
    def __init__(self, path: Path, packages_dir: Path):
        self.path = path
        self.directory = path.parent
        self.spec = self.directory.relative_to(packages_dir).as_posix()
        with path.open("rb") as handle:
            self.data = tomllib.load(handle)

        package = self.data.get("package", {})
        source = self.data.get("source", {})
        build = self.data.get("build", {})
        module = self.data.get("module", {})

        self.schema = self.data.get("schema")
        self.name = package.get("name", "")
        self.version = package.get("version", "")
        self.description = package.get("description", self.name)
        self.explicit_dependencies = as_list(package.get("dependencies"), "package.dependencies")
        self.source = source
        self.build = build
        self.module = module
        self.tests = self.data.get("tests", [])

    @property
    def source_url(self) -> str:
        return str(self.source.get("url", ""))

    @property
    def sha256(self) -> str:
        return str(self.source.get("sha256", ""))

    @property
    def source_directory(self) -> str:
        return str(self.source.get("directory", ""))

    @property
    def archive(self) -> str:
        configured = self.source.get("archive")
        if configured:
            return str(configured)
        return self.source_url.rstrip("/").rsplit("/", 1)[-1]


class Repository:
    def __init__(self, root: Path):
        self.root = root.resolve()
        self.packages_dir = self.root / "packages"
        self.recipes: dict[str, Recipe] = {}
        for path in sorted(self.packages_dir.glob("**/package.toml")):
            recipe = Recipe(path, self.packages_dir)
            if recipe.spec in self.recipes:
                die(f"receita duplicada: {recipe.spec}")
            self.recipes[recipe.spec] = recipe

    def get(self, spec: str) -> Recipe:
        try:
            return self.recipes[spec.strip("/")]
        except KeyError:
            die(f"pacote desconhecido: {spec}")

    def parent(self, recipe: Recipe) -> Recipe | None:
        # The immediate parent is the longest name/version prefix that is
        # itself a recipe, encoding the toolchain hierarchy (e.g. gcc/9.5.0).
        parts = recipe.spec.split("/")
        candidates = []
        for index in range(2, len(parts), 2):
            candidate = "/".join(parts[:index])
            if candidate in self.recipes:
                candidates.append(self.recipes[candidate])
        return candidates[-1] if candidates else None

    def resolve_dependency(self, recipe: Recipe, dependency: str) -> str:
        dependency = dependency.strip("/")
        if dependency in self.recipes:
            return dependency

        # Resolve a bare dependency relative to the requesting recipe by
        # walking up its hierarchy, matching the generated module layout.
        context = recipe.spec.split("/")[:-2]
        while context:
            candidate = "/".join(context + dependency.split("/"))
            if candidate in self.recipes:
                return candidate
            context = context[:-2]
        die(f"{recipe.spec}: dependência não encontrada: {dependency}")

    def dependencies(self, recipe: Recipe) -> list[str]:
        # Effective dependencies: the implicit parent plus explicit deps,
        # deduplicated while preserving order.
        result: list[str] = []
        parent = self.parent(recipe)
        if parent:
            result.append(parent.spec)
        for dependency in recipe.explicit_dependencies:
            resolved = self.resolve_dependency(recipe, dependency)
            if resolved not in result:
                result.append(resolved)
        return result

    def children(self, recipe: Recipe) -> list[Recipe]:
        return [candidate for candidate in self.recipes.values() if self.parent(candidate) is recipe]

    def dependents(self, recipe: Recipe) -> list[Recipe]:
        affected = {recipe.spec}
        result: list[Recipe] = []
        while True:
            added = []
            for candidate in self.recipes.values():
                if candidate.spec in affected:
                    continue
                if any(dependency in affected for dependency in self.dependencies(candidate)):
                    affected.add(candidate.spec)
                    added.append(candidate)
            if not added:
                return result
            result.extend(added)

    def validate_recipe(self, recipe: Recipe, require_lock: bool = True) -> list[str]:
        errors: list[str] = []
        allowed_fields = {
            "root": {"schema", "package", "source", "build", "module", "tests"},
            "package": {"name", "version", "description", "dependencies"},
            "source": {"url", "archive", "sha256", "directory"},
            "build": {
                "system",
                "arguments",
                "install_arguments",
                "targets",
                "requires",
                "configure",
                "script",
                "in_source",
                "environment",
            },
            "module": {"family", "root_environment", "paths", "environment"},
            "test": {"type", "path", "command"},
        }

        def reject_unknown(label: str, table: dict[str, object], allowed: set[str]) -> None:
            for field in sorted(set(table) - allowed):
                errors.append(f"campo desconhecido em {label}: {field}")

        reject_unknown("raiz", recipe.data, allowed_fields["root"])
        reject_unknown("package", recipe.data.get("package", {}), allowed_fields["package"])
        reject_unknown("source", recipe.source, allowed_fields["source"])
        reject_unknown("build", recipe.build, allowed_fields["build"])
        reject_unknown("module", recipe.module, allowed_fields["module"])
        # Specs are name/version pairs; the final pair must match the declared
        # package name and version.
        parts = recipe.spec.split("/")
        if recipe.schema != SCHEMA_VERSION:
            errors.append(f"schema deve ser {SCHEMA_VERSION}")
        if len(parts) < 2 or len(parts) % 2:
            errors.append("o caminho deve ser composto por pares nome/versão")
        elif parts[-2:] != [recipe.name, recipe.version]:
            errors.append(
                f"package.name/version ({recipe.name}/{recipe.version}) não corresponde ao caminho"
            )
        if not recipe.source_url:
            errors.append("source.url ausente")
        if not recipe.source_directory:
            errors.append("source.directory ausente")
        if require_lock and not SHA256_RE.fullmatch(recipe.sha256):
            errors.append("source.sha256 deve conter 64 caracteres hexadecimais")
        system = recipe.build.get("system")
        if system not in BUILD_SYSTEMS:
            errors.append(f"build.system inválido: {system!r}")
        if system == "script" and not recipe.build.get("script"):
            errors.append("build.script é obrigatório para build.system='script'")
        if not isinstance(recipe.tests, list):
            errors.append("tests deve ser uma lista de tabelas")
        else:
            for index, test in enumerate(recipe.tests, start=1):
                if isinstance(test, dict):
                    reject_unknown(f"tests[{index}]", test, allowed_fields["test"])
                else:
                    errors.append(f"tests[{index}] deve ser uma tabela")
        try:
            self.dependencies(recipe)
        except RecipeError as exc:
            errors.append(str(exc))
        return errors

    def validate(self, selected: list[Recipe], require_lock: bool = True) -> None:
        failures = []
        for recipe in selected:
            for error in self.validate_recipe(recipe, require_lock=require_lock):
                failures.append(f"{recipe.spec}: {error}")
        if failures:
            die("manifestos inválidos:\n  - " + "\n  - ".join(failures))
        for recipe in selected:
            self.plan(recipe.spec)

    def plan(self, spec: str) -> list[str]:
        # Depth-first topological sort producing a build order with every
        # dependency before its dependents. "visiting" also detects cycles.
        ordered: list[str] = []
        visiting: list[str] = []
        visited: set[str] = set()

        def visit(current: str) -> None:
            if current in visiting:
                cycle = " -> ".join(visiting + [current])
                die(f"ciclo de dependências: {cycle}")
            if current in visited:
                return
            visiting.append(current)
            recipe = self.get(current)
            for dependency in self.dependencies(recipe):
                visit(dependency)
            visiting.pop()
            visited.add(current)
            ordered.append(current)

        visit(spec)
        return ordered


class Runtime:
    def __init__(self, repository: Repository):
        root = Path(os.environ.get("TINYHPC_ROOT", "/opt/hpc"))
        self.repository = repository
        self.hpc_root = root
        self.cache = Path(os.environ.get("HPC_CACHE", root / "cache"))
        self.sources = Path(os.environ.get("HPC_SRC", root / "src"))
        self.builds = Path(os.environ.get("HPC_BUILD", root / "build"))
        self.software = Path(os.environ.get("HPC_SOFTWARE", root / "software"))
        self.modulefiles = Path(os.environ.get("HPC_MODULEFILES", root / "modulefiles"))
        self.logs = Path(os.environ.get("HPC_LOGS", root / "logs"))
        self.jobs = str(os.environ.get("HPC_JOBS", "4"))

    def require_layout(self) -> None:
        missing = [path for path in self.layout() if not path.is_dir()]
        if missing:
            die(f"{missing[0]} não existe; rode o bootstrap do TinyHPC")

    def layout(self) -> list[Path]:
        return [self.cache, self.sources, self.builds, self.software, self.modulefiles, self.logs]

    def prefix(self, recipe: Recipe) -> Path:
        # Keep package identity hierarchical without nesting one package's
        # owned files inside another package's replaceable installation.
        return self.software / recipe.spec / ".prefix"

    def source_path(self, recipe: Recipe) -> Path:
        return self.sources / recipe.source_directory

    def build_path(self, recipe: Recipe) -> Path:
        return self.builds / recipe.spec

    def modulefile_path(self, recipe: Recipe) -> Path:
        return self.modulefiles / f"{recipe.spec}.lua"

    def marker_path(self, recipe: Recipe) -> Path:
        return self.prefix(recipe) / ".tinyhpc-installed"

    def backup_path(self, recipe: Recipe) -> Path:
        prefix = self.prefix(recipe)
        return prefix.with_name(f"{prefix.name}.tinyhpc-backup")

    def modulefile_backup_path(self, recipe: Recipe) -> Path:
        modulefile = self.modulefile_path(recipe)
        return modulefile.with_suffix(modulefile.suffix + ".tinyhpc-backup")

    def installed(self, recipe: Recipe) -> bool:
        state = self.installation_state(recipe)
        return (
            state is not None
            and state.get("schema") == 2
            and state.get("fingerprint") == self.recipe_fingerprint(recipe)
        )

    def installation_state(self, recipe: Recipe) -> dict[str, object] | None:
        marker = self.marker_path(recipe)
        if not marker.is_file():
            return None
        try:
            state = json.loads(marker.read_text())
        except (json.JSONDecodeError, OSError):
            return None
        if not isinstance(state, dict) or state.get("spec") != recipe.spec:
            return None
        return state

    def recipe_fingerprint(
        self,
        recipe: Recipe,
        cache: dict[str, str] | None = None,
        visiting: set[str] | None = None,
    ) -> str:
        cache = {} if cache is None else cache
        visiting = set() if visiting is None else visiting
        if recipe.spec in cache:
            return cache[recipe.spec]
        if recipe.spec in visiting:
            die(f"ciclo de dependências ao calcular fingerprint: {recipe.spec}")
        visiting.add(recipe.spec)

        files = [recipe.path]
        script = recipe.build.get("script")
        if script:
            files.append(recipe.directory / str(script))
        for test in recipe.tests:
            if isinstance(test, dict) and test.get("type") == "script":
                files.append(recipe.directory / str(test.get("path", "test.sh")))
        files.extend(sorted((recipe.directory / "patches").glob("*.patch")))

        digest = hashlib.sha256()
        contents = b""
        for path in files:
            digest.update(path.relative_to(recipe.directory).as_posix().encode())
            if path.is_file():
                content = path.read_bytes()
                digest.update(content)
                contents += content
        for variable in ("HPC_OPT_FLAGS", "HPC_OPENBLAS_DYNAMIC_ARCH"):
            if f"${{{variable}}}".encode() in contents:
                digest.update(variable.encode())
                digest.update(os.environ.get(variable, "").encode())
        for dependency in self.repository.dependencies(recipe):
            digest.update(dependency.encode())
            digest.update(
                self.recipe_fingerprint(
                    self.repository.get(dependency), cache=cache, visiting=visiting
                ).encode()
            )

        visiting.remove(recipe.spec)
        cache[recipe.spec] = digest.hexdigest()
        return cache[recipe.spec]

    def expand(self, value: str, recipe: Recipe) -> str:
        # Substitute {prefix}/{source}/{build}/{jobs} placeholders, then expand
        # any remaining $VARS (e.g. ${GMP_ROOT}) from the environment.
        replacements = {
            "{prefix}": str(self.prefix(recipe)),
            "{source}": str(self.source_path(recipe)),
            "{build}": str(self.build_path(recipe)),
            "{jobs}": self.jobs,
        }
        for key, replacement in replacements.items():
            value = value.replace(key, replacement)
        return os.path.expandvars(value)

    def fetch(self, recipe: Recipe) -> Path:
        destination = self.cache / recipe.archive
        if not destination.exists():
            note(f"baixando {recipe.archive}")
            temporary = destination.with_suffix(destination.suffix + ".part")
            try:
                with urllib.request.urlopen(recipe.source_url) as response, temporary.open("wb") as output:
                    shutil.copyfileobj(response, output)
                temporary.replace(destination)
            finally:
                temporary.unlink(missing_ok=True)
        else:
            note(f"usando cache {recipe.archive}")

        digest = file_sha256(destination)
        if not SHA256_RE.fullmatch(recipe.sha256):
            die(f"{recipe.spec}: checksum não travado; SHA-256 atual: {digest}")
        if digest != recipe.sha256:
            die(f"{recipe.spec}: checksum inválido: {digest}")
        return destination

    def extract(self, recipe: Recipe, archive: Path) -> Path:
        source = self.source_path(recipe)
        shutil.rmtree(source, ignore_errors=True)
        note(f"extraindo {archive.name}")
        with tarfile.open(archive) as bundle:
            base = self.sources.resolve()
            # Reject members that resolve outside the source tree before any
            # extraction, blocking path traversal via crafted tarballs.
            for member in bundle.getmembers():
                target = (self.sources / member.name).resolve()
                if base != target and base not in target.parents:
                    die(f"arquivo inseguro no tarball: {member.name}")
            bundle.extractall(self.sources)
        if not source.is_dir():
            die(f"source.directory não encontrado após extração: {source}")
        return source

    def apply_patches(self, recipe: Recipe, source: Path) -> None:
        patch_directory = recipe.directory / "patches"
        for patch in sorted(patch_directory.glob("*.patch")):
            note(f"aplicando patch {patch.name}")
            self.run(["patch", "-d", str(source), "-p1", "-i", str(patch)])

    def environment(self, recipe: Recipe) -> dict[str, str]:
        environment = dict(os.environ)
        configured = recipe.build.get("environment", {})
        if not isinstance(configured, dict):
            die(f"{recipe.spec}: build.environment deve ser uma tabela")
        for key, value in configured.items():
            environment[str(key)] = self.expand(str(value), recipe)
        environment["HPC_PREFIX"] = str(self.prefix(recipe))
        environment["HPC_PACKAGE_DIR"] = str(recipe.directory)
        return environment

    def run(
        self,
        command: list[str],
        *,
        cwd: Path | None = None,
        environment: dict[str, str] | None = None,
    ) -> None:
        rendered = " ".join(command)
        note(rendered)
        subprocess.run(command, cwd=cwd, env=environment, check=True)

    def build(self, recipe: Recipe, source: Path) -> None:
        # Dispatch to the configured build system; each branch expands
        # placeholders and runs configure/build/install (or the equivalent).
        system = recipe.build["system"]
        prefix = self.prefix(recipe)
        build = self.build_path(recipe)
        environment = self.environment(recipe)
        required = as_list(recipe.build.get("requires"), "build.requires")
        for command in required:
            if shutil.which(command, path=environment.get("PATH")) is None:
                die(f"{recipe.spec}: comando obrigatório ausente: {command}")

        arguments = [self.expand(item, recipe) for item in as_list(recipe.build.get("arguments"), "build.arguments")]
        install_arguments = [
            self.expand(item, recipe)
            for item in as_list(recipe.build.get("install_arguments"), "build.install_arguments")
        ]
        targets = as_list(recipe.build.get("targets"), "build.targets")

        shutil.rmtree(build, ignore_errors=True)
        if system != "make" or not recipe.build.get("in_source", True):
            build.mkdir(parents=True, exist_ok=True)
        prefix.parent.mkdir(parents=True, exist_ok=True)

        if system == "autotools":
            configure = source / str(recipe.build.get("configure", "configure"))
            self.run([str(configure), f"--prefix={prefix}", *arguments], cwd=build, environment=environment)
            self.run(["make", f"-j{self.jobs}", *targets], cwd=build, environment=environment)
            self.run(["make", "install", *install_arguments], cwd=build, environment=environment)
        elif system == "cmake":
            self.run(
                ["cmake", "-S", str(source), "-B", str(build), f"-DCMAKE_INSTALL_PREFIX={prefix}", *arguments],
                environment=environment,
            )
            command = ["cmake", "--build", str(build), "--parallel", self.jobs]
            if targets:
                command += ["--target", *targets]
            self.run(command, environment=environment)
            self.run(["cmake", "--install", str(build), *install_arguments], environment=environment)
        elif system == "make":
            work = source if recipe.build.get("in_source", True) else build
            self.run(["make", f"-j{self.jobs}", *arguments, *targets], cwd=work, environment=environment)
            self.run(["make", *arguments, *install_arguments, "install"], cwd=work, environment=environment)
        elif system == "script":
            script = recipe.directory / str(recipe.build["script"])
            self.run(["bash", str(script)], cwd=recipe.directory, environment=environment)

    def test(self, recipe: Recipe) -> None:
        environment = self.environment(recipe)
        prefix = self.prefix(recipe)
        for index, test in enumerate(recipe.tests, start=1):
            if not isinstance(test, dict):
                die(f"{recipe.spec}: tests[{index}] deve ser uma tabela")
            kind = test.get("type")
            if kind in {"file", "executable", "directory"}:
                path = prefix / str(test.get("path", ""))
                valid = path.is_file() if kind == "file" else path.is_dir() if kind == "directory" else os.access(path, os.X_OK)
                if not valid:
                    die(f"{recipe.spec}: teste {kind} falhou: {path}")
            elif kind == "command":
                command = [self.expand(item, recipe) for item in as_list(test.get("command"), "tests.command")]
                if not command:
                    die(f"{recipe.spec}: teste command vazio")
                self.run(command, environment=environment)
            elif kind == "script":
                script = recipe.directory / str(test.get("path", "test.sh"))
                self.run(["bash", str(script)], cwd=recipe.directory, environment=environment)
            else:
                die(f"{recipe.spec}: tipo de teste inválido: {kind!r}")

    def render_modulefile(self, recipe: Recipe) -> str:
        dependencies = self.repository.dependencies(recipe)
        lines = [
            f"help({lua_quote(recipe.description)})",
            f"whatis({lua_quote('Name: ' + recipe.name)})",
            f"whatis({lua_quote('Version: ' + recipe.version)})",
            "",
            'local hpc_root = os.getenv("TINYHPC_ROOT") or "/opt/hpc"',
            f"local root = pathJoin(hpc_root, {lua_quote('software/' + recipe.spec + '/.prefix')})",
        ]
        family = recipe.module.get("family")
        if family:
            lines.append(f"family({lua_quote(str(family))})")
        for dependency in dependencies:
            lines.append(f"depends_on({lua_quote(dependency)})")
        # Expose this spec's own modulefiles subdir so nested toolchains are
        # discoverable through hierarchical MODULEPATH lookup.
        if self.repository.children(recipe):
            lines.append(
                f"prepend_path(\"MODULEPATH\", pathJoin(hpc_root, {lua_quote('modulefiles/' + recipe.spec)}))"
            )

        paths = recipe.module.get("paths", {})
        if not isinstance(paths, dict):
            die(f"{recipe.spec}: module.paths deve ser uma tabela")
        for variable, values in paths.items():
            for value in as_list(values, f"module.paths.{variable}"):
                lines.append(f"prepend_path({lua_quote(str(variable))}, pathJoin(root, {lua_quote(value)}))")

        for variable in as_list(recipe.module.get("root_environment"), "module.root_environment"):
            lines.append(f"setenv({lua_quote(variable)}, root)")
        configured_environment = recipe.module.get("environment", {})
        if not isinstance(configured_environment, dict):
            die(f"{recipe.spec}: module.environment deve ser uma tabela")
        for variable, value in configured_environment.items():
            value = str(value)
            if value == "{root}":
                rendered = "root"
            elif value.startswith("{root}/"):
                rendered = f"pathJoin(root, {lua_quote(value[7:])})"
            else:
                rendered = lua_quote(value)
            lines.append(f"setenv({lua_quote(str(variable))}, {rendered})")
        return "\n".join(lines) + "\n"

    def sync_modulefile(self, recipe: Recipe) -> None:
        # Reconcile stale reverse dependencies every time an installed module
        # is synchronized, making interrupted invalidation retryable.
        for dependent in self.repository.dependents(recipe):
            if not self.installed(dependent):
                self.modulefile_path(dependent).unlink(missing_ok=True)
        target = self.modulefile_path(recipe)
        content = self.render_modulefile(recipe)
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or target.read_text() != content:
            target.write_text(content)
            note(f"modulefile de {recipe.spec} sincronizado")

    def install_one(self, recipe: Recipe) -> None:
        self.require_layout()
        self.repository.validate([recipe])
        prefix = self.prefix(recipe)
        backup = self.backup_path(recipe)
        modulefile = self.modulefile_path(recipe)
        modulefile_backup = self.modulefile_backup_path(recipe)

        if backup.exists():
            if self.installation_state(recipe) is not None:
                shutil.rmtree(backup, ignore_errors=True)
                modulefile_backup.unlink(missing_ok=True)
            else:
                # Recover the last complete installation after interruption.
                shutil.rmtree(prefix, ignore_errors=True)
                backup.rename(prefix)
                if modulefile_backup.is_file():
                    modulefile.parent.mkdir(parents=True, exist_ok=True)
                    modulefile_backup.replace(modulefile)
        if self.installed(recipe):
            modulefile_backup.unlink(missing_ok=True)
            self.sync_modulefile(recipe)
            note(f"{recipe.spec} já instalado")
            return
        archive = self.fetch(recipe)
        source = self.extract(recipe, archive)
        self.apply_patches(recipe, source)
        had_previous_installation = prefix.exists()
        had_previous_modulefile = modulefile.is_file()
        modulefile_backup.unlink(missing_ok=True)
        if had_previous_modulefile:
            modulefile_backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(modulefile, modulefile_backup)
        if had_previous_installation:
            prefix.rename(backup)
        try:
            self.build(recipe, source)
            self.test(recipe)
            marker = self.marker_path(recipe)
            marker.parent.mkdir(parents=True, exist_ok=True)
            marker.write_text(
                json.dumps(
                    {
                        "schema": 2,
                        "spec": recipe.spec,
                        "fingerprint": self.recipe_fingerprint(recipe),
                    }
                )
                + "\n"
            )
            self.sync_modulefile(recipe)
        except BaseException:
            shutil.rmtree(prefix, ignore_errors=True)
            if had_previous_installation:
                backup.rename(prefix)
            if had_previous_modulefile:
                modulefile_backup.replace(modulefile)
            else:
                modulefile.unlink(missing_ok=True)
            raise
        shutil.rmtree(backup, ignore_errors=True)
        modulefile_backup.unlink(missing_ok=True)
        note(f"{recipe.spec} OK")

    def clean(self, recipe: Recipe) -> None:
        shutil.rmtree(self.build_path(recipe), ignore_errors=True)
        shutil.rmtree(self.source_path(recipe), ignore_errors=True)
        note("build e source extraído removidos; cache preservado")

    def remove(self, recipe: Recipe) -> None:
        shutil.rmtree(self.prefix(recipe), ignore_errors=True)
        shutil.rmtree(self.backup_path(recipe), ignore_errors=True)
        self.modulefile_path(recipe).unlink(missing_ok=True)
        self.modulefile_backup_path(recipe).unlink(missing_ok=True)
        for dependent in self.repository.dependents(recipe):
            self.modulefile_path(dependent).unlink(missing_ok=True)
        note(f"{recipe.spec} removido")


def replace_source_checksum(path: Path, digest: str) -> None:
    # Rewrite only the sha256 value inside the [source] table, leaving the
    # rest of the file verbatim (used by "hpc lock").
    text = path.read_text()
    pattern = re.compile(r"(?ms)(^\[source\]\s*.*?^sha256\s*=\s*)[^\n]+")
    updated, count = pattern.subn(lambda match: match.group(1) + json.dumps(digest), text, count=1)
    if count != 1:
        die(f"não foi possível localizar source.sha256 em {path}")
    path.write_text(updated)


def command_new(repository: Repository, spec: str, system: str) -> None:
    parts = spec.strip("/").split("/")
    if len(parts) < 2 or len(parts) % 2:
        die("a spec deve ser composta por pares nome/versão")
    path = repository.packages_dir.joinpath(*parts) / "package.toml"
    if path.exists():
        die(f"receita já existe: {spec}")
    path.parent.mkdir(parents=True, exist_ok=True)
    name, version = parts[-2:]
    path.write_text(
        f'''schema = 1\n\n[package]\nname = {json.dumps(name)}\nversion = {json.dumps(version)}\ndescription = {json.dumps(name)}\ndependencies = []\n\n[source]\nurl = ""\nsha256 = "UNSET"\ndirectory = {json.dumps(name + "-" + version)}\n\n[build]\nsystem = {json.dumps(system)}\narguments = []\n\n[module]\nroot_environment = [{json.dumps(name.upper().replace("-", "_") + "_ROOT")}]\n\n[module.paths]\nPATH = ["bin"]\nLD_LIBRARY_PATH = ["lib"]\nCPATH = ["include"]\n'''
    )
    print(path)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="hpc-recipe")
    result.add_argument("--repo", type=Path, required=True)
    subcommands = result.add_subparsers(dest="command", required=True)
    for name in ("info", "plan", "dependencies", "installed", "sync-module", "install-one", "clean", "remove", "lock"):
        command = subcommands.add_parser(name)
        command.add_argument("spec")
    validate = subcommands.add_parser("validate")
    validate.add_argument("spec", nargs="?")
    subcommands.add_parser("list")
    subcommands.add_parser("config")
    environment = subcommands.add_parser("environment")
    environment.add_argument("--shell", choices=("tsv", "bash", "zsh", "fish"), default="tsv")
    render = subcommands.add_parser("render-module")
    render.add_argument("spec")
    new = subcommands.add_parser("new")
    new.add_argument("spec")
    new.add_argument("--build-system", choices=sorted(BUILD_SYSTEMS), default="autotools")
    return result


def main() -> int:
    arguments = parser().parse_args()
    user_configuration = apply_configuration(arguments.repo.resolve())
    repository = Repository(arguments.repo)
    runtime = Runtime(repository)
    command = arguments.command

    if command == "environment":
        render_environment(arguments.shell)
    elif command == "config":
        print(f"config={user_configuration or 'defaults'}")
        for key in CONFIG_ENVIRONMENT:
            print(f"{key}={os.environ[key]}")
    elif command == "list":
        print("\n".join(sorted(repository.recipes)))
    elif command == "new":
        command_new(repository, arguments.spec, arguments.build_system)
    elif command == "validate":
        selected = [repository.get(arguments.spec)] if arguments.spec else list(repository.recipes.values())
        repository.validate(selected)
        for recipe in sorted(selected, key=lambda item: item.spec):
            print(f"{recipe.spec}: OK")
    else:
        recipe = repository.get(arguments.spec)
        if command == "info":
            print(f"name={recipe.name}")
            print(f"version={recipe.version}")
            print(f"source={recipe.source_url}")
            print(f"prefix={runtime.prefix(recipe)}")
            print(f"module={recipe.spec}")
            print(f"parent={(repository.parent(recipe) or recipe).spec if repository.parent(recipe) else ''}")
            print(f"depends={','.join(repository.dependencies(recipe))}")
        elif command == "plan":
            ordered = repository.plan(recipe.spec)
            repository.validate([repository.get(spec) for spec in ordered])
            print("\n".join(ordered))
        elif command == "dependencies":
            print("\n".join(repository.dependencies(recipe)))
        elif command == "installed":
            return 0 if runtime.installed(recipe) else 1
        elif command == "sync-module":
            runtime.sync_modulefile(recipe)
        elif command == "render-module":
            print(runtime.render_modulefile(recipe), end="")
        elif command == "install-one":
            runtime.install_one(recipe)
        elif command == "clean":
            runtime.clean(recipe)
        elif command == "remove":
            runtime.remove(recipe)
        elif command == "lock":
            runtime.require_layout()
            archive = runtime.cache / recipe.archive
            if not archive.exists():
                note(f"baixando {recipe.archive}")
                with urllib.request.urlopen(recipe.source_url) as response, archive.open("wb") as output:
                    shutil.copyfileobj(response, output)
            digest = file_sha256(archive)
            replace_source_checksum(recipe.path, digest)
            print(f"sha256={digest}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RecipeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
    except subprocess.CalledProcessError as exc:
        print(f"ERROR: comando falhou com status {exc.returncode}", file=sys.stderr)
        raise SystemExit(exc.returncode)
