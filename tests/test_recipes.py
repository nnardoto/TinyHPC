from pathlib import Path
import hashlib
import io
import json
import os
import sys
import tempfile
import unittest
from unittest import mock


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPOSITORY_ROOT / "lib"))

from recipe import RecipeError, Repository, Runtime, apply_configuration  # noqa: E402


QE_SPEC = "gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6"
OPENMX_SPEC = "gcc/9.5.0/openmpi/5.0.8/openmx/4.0.1"
GCC16_SPEC = "gcc/16.2.0"
GCC16_QE_SPEC = "gcc/16.2.0/openmpi/5.0.8/quantum-espresso/7.6"
GCC16_OPENMX_SPEC = "gcc/16.2.0/openmpi/5.0.8/openmx/4.0.1"


class HierarchyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repository = Repository(REPOSITORY_ROOT)

    def test_all_manifests_validate(self):
        self.repository.validate(list(self.repository.recipes.values()))

    def test_quantum_espresso_plan_is_reproducible(self):
        self.assertEqual(
            self.repository.plan(QE_SPEC),
            [
                "gmp/6.1.0",
                "mpfr/4.1.0",
                "mpc/1.2.1",
                "isl/0.24",
                "gcc/9.5.0",
                "gcc/9.5.0/openmpi/5.0.8",
                "gcc/9.5.0/openblas/0.3.30",
                "gcc/9.5.0/fftw/3.3.10",
                "gcc/9.5.0/openmpi/5.0.8/scalapack/2.2.0",
                QE_SPEC,
            ],
        )

    def test_openmx_plan_includes_numerical_dependencies(self):
        self.assertEqual(
            self.repository.plan(OPENMX_SPEC),
            [
                "gmp/6.1.0",
                "mpfr/4.1.0",
                "mpc/1.2.1",
                "isl/0.24",
                "gcc/9.5.0",
                "gcc/9.5.0/openmpi/5.0.8",
                "gcc/9.5.0/fftw/3.3.10",
                "gcc/9.5.0/openblas/0.3.30",
                "gcc/9.5.0/openmpi/5.0.8/scalapack/2.2.0",
                OPENMX_SPEC,
            ],
        )

    def test_gcc_16_plan_uses_matching_prerequisites(self):
        self.assertEqual(
            self.repository.plan(GCC16_SPEC),
            [
                "gmp/6.3.0",
                "mpfr/4.2.2",
                "mpc/1.3.1",
                "isl/0.24",
                GCC16_SPEC,
            ],
        )

    def test_gcc_16_scientific_stack_plans_are_complete(self):
        common = [
            "gmp/6.3.0",
            "mpfr/4.2.2",
            "mpc/1.3.1",
            "isl/0.24",
            GCC16_SPEC,
            "gcc/16.2.0/openmpi/5.0.8",
        ]
        self.assertEqual(
            self.repository.plan(GCC16_QE_SPEC),
            [
                *common,
                "gcc/16.2.0/openblas/0.3.30",
                "gcc/16.2.0/fftw/3.3.10",
                "gcc/16.2.0/openmpi/5.0.8/scalapack/2.2.0",
                GCC16_QE_SPEC,
            ],
        )
        self.assertEqual(
            self.repository.plan(GCC16_OPENMX_SPEC),
            [
                *common,
                "gcc/16.2.0/fftw/3.3.10",
                "gcc/16.2.0/openblas/0.3.30",
                "gcc/16.2.0/openmpi/5.0.8/scalapack/2.2.0",
                GCC16_OPENMX_SPEC,
            ],
        )

    def test_scientific_stacks_use_native_hybrid_configuration(self):
        for compiler in ("gcc/9.5.0", GCC16_SPEC):
            with self.subTest(compiler=compiler):
                openblas = self.repository.get(f"{compiler}/openblas/0.3.30")
                self.assertIn(
                    "DYNAMIC_ARCH=${HPC_OPENBLAS_DYNAMIC_ARCH}",
                    openblas.build["arguments"],
                )
                self.assertIn("COMMON_OPT=${HPC_OPT_FLAGS}", openblas.build["arguments"])
                self.assertIn("USE_THREAD=0", openblas.build["arguments"])
                qe = self.repository.get(
                    f"{compiler}/openmpi/5.0.8/quantum-espresso/7.6"
                )
                flags = " ".join(qe.build["arguments"])
                self.assertIn("${HPC_OPT_FLAGS}", flags)
                self.assertIn("-floop-nest-optimize", flags)

    def test_gcc_toolchains_enable_graphite_and_runtime_libraries(self):
        for spec in ("gcc/9.5.0", GCC16_SPEC):
            with self.subTest(spec=spec):
                recipe = self.repository.get(spec)
                self.assertIn("isl/0.24", self.repository.dependencies(recipe))
                self.assertIn("--with-isl=${ISL_ROOT}", recipe.build["arguments"])
                modulefile = Runtime(self.repository).render_modulefile(recipe)
                self.assertIn('prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib64"))', modulefile)

    def test_parent_dependency_is_implicit(self):
        openmpi = self.repository.get("gcc/9.5.0/openmpi/5.0.8")
        self.assertEqual(self.repository.dependencies(openmpi), ["gcc/9.5.0"])

    def test_lateral_dependencies_use_nearest_context(self):
        qe = self.repository.get(QE_SPEC)
        self.assertEqual(
            self.repository.dependencies(qe),
            [
                "gcc/9.5.0/openmpi/5.0.8",
                "gcc/9.5.0/openblas/0.3.30",
                "gcc/9.5.0/fftw/3.3.10",
                "gcc/9.5.0/openmpi/5.0.8/scalapack/2.2.0",
            ],
        )

    def test_parent_module_exposes_children(self):
        gcc = self.repository.get("gcc/9.5.0")
        modulefile = Runtime(self.repository).render_modulefile(gcc)
        self.assertIn('modulefiles/gcc/9.5.0', modulefile)
        self.assertIn('software/gcc/9.5.0/.prefix', modulefile)
        self.assertIn('setenv("CC", pathJoin(root, "bin/gcc"))', modulefile)

    def test_reverse_dependencies_are_transitive(self):
        gmp = self.repository.get("gmp/6.3.0")
        dependents = {recipe.spec for recipe in self.repository.dependents(gmp)}
        self.assertIn("mpfr/4.2.2", dependents)
        self.assertIn("mpc/1.3.1", dependents)
        self.assertIn(GCC16_SPEC, dependents)
        self.assertIn(GCC16_QE_SPEC, dependents)


class ValidationTests(unittest.TestCase):
    def test_dependency_cycle_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_recipe(root, "a/1", ["b/1"])
            self.write_recipe(root, "b/1", ["a/1"])
            repository = Repository(root)
            with self.assertRaisesRegex(RecipeError, "ciclo"):
                repository.plan("a/1")

    def test_unknown_field_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_recipe(root, "a/1", [])
            manifest = root / "packages/a/1/package.toml"
            manifest.write_text(manifest.read_text().replace("system =", "systen ="))
            repository = Repository(root)
            with self.assertRaisesRegex(RecipeError, "campo desconhecido em build: systen"):
                repository.validate([repository.get("a/1")])

    def test_mirror_source_requires_path_and_excludes_url(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_recipe(root, "a/1", [])
            manifest = root / "packages/a/1/package.toml"
            manifest.write_text(
                manifest.read_text().replace(
                    'url = "https://example.invalid/a.tar.gz"',
                    'url = "https://example.invalid/a.tar.gz"\nmirror = "gnu"',
                )
            )
            repository = Repository(root)
            errors = repository.validate_recipe(repository.get("a/1"))
            self.assertIn("source.url e source.mirror/path são mutuamente exclusivos", errors)
            self.assertIn("source.path é obrigatório quando source.mirror é usado", errors)

    def test_archive_must_be_a_cache_basename(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_recipe(root, "a/1", [])
            manifest = root / "packages/a/1/package.toml"
            manifest.write_text(
                manifest.read_text().replace(
                    'sha256 =', 'archive = "../outside.tar.gz"\nsha256 ='
                )
            )
            repository = Repository(root)
            recipe = repository.get("a/1")
            errors = repository.validate_recipe(recipe)
            self.assertIn("source.archive deve ser um nome de arquivo sem diretórios", errors)
            with self.assertRaisesRegex(RecipeError, "source.archive"):
                Runtime(repository).cache_path(recipe)

    def test_fetch_tries_mirrors_in_configured_order(self):
        payload = b"mirror archive"
        digest = hashlib.sha256(payload).hexdigest()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_recipe(root, "a/1", [])
            manifest = root / "packages/a/1/package.toml"
            manifest.write_text(
                manifest.read_text()
                .replace(
                    'url = "https://example.invalid/a.tar.gz"',
                    'mirror = "gnu"\npath = "a/a.tar.gz"',
                )
                .replace("0" * 64, digest)
            )
            repository = Repository(root)
            recipe = repository.get("a/1")
            repository.validate([recipe])
            runtime = Runtime(repository)
            runtime.cache = root / "cache"
            runtime.cache.mkdir()
            attempted = []

            def open_url(url, timeout):
                attempted.append(url)
                if len(attempted) == 1:
                    return io.BytesIO(b"corrupt archive")
                return io.BytesIO(payload)

            mirrors = {"gnu": ["https://primary.example/gnu/", "https://mirror.example/gnu"]}
            with mock.patch.dict(os.environ, {"HPC_MIRRORS": json.dumps(mirrors)}), \
                    mock.patch("recipe.urllib.request.urlopen", side_effect=open_url):
                archive = runtime.fetch(recipe)

            self.assertEqual(recipe.archive, "a.tar.gz")
            self.assertEqual(archive.read_bytes(), payload)
            self.assertEqual(
                attempted,
                [
                    "https://primary.example/gnu/a/a.tar.gz",
                    "https://mirror.example/gnu/a/a.tar.gz",
                ],
            )

    def test_install_marker_is_invalidated_when_recipe_changes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_recipe(root, "a/1", [])
            repository = Repository(root)
            with mock.patch.dict(
                os.environ,
                {
                    "TINYHPC_ROOT": str(root / "stack"),
                    "HPC_OPT_FLAGS": "-O3",
                    "HPC_OPENBLAS_DYNAMIC_ARCH": "1",
                },
            ):
                runtime = Runtime(repository)
                runtime.software = root / "stack/software"
                recipe = repository.get("a/1")
                marker = runtime.marker_path(recipe)
                marker.parent.mkdir(parents=True, exist_ok=True)
                marker.write_text(
                    json.dumps(
                        {
                            "schema": 2,
                            "spec": recipe.spec,
                            "fingerprint": runtime.recipe_fingerprint(recipe),
                        }
                    )
                )
                self.assertTrue(runtime.installed(recipe))
                recipe.path.write_text(recipe.path.read_text() + "\n# changed\n")
                self.assertFalse(runtime.installed(recipe))

    def test_failed_upgrade_restores_previous_installation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_recipe(root, "a/1", [])
            repository = Repository(root)
            runtime = Runtime(repository)
            stack = root / "stack"
            runtime.cache = stack / "cache"
            runtime.sources = stack / "src"
            runtime.builds = stack / "build"
            runtime.software = stack / "software"
            runtime.modulefiles = stack / "modulefiles"
            runtime.logs = stack / "logs"
            for path in runtime.layout():
                path.mkdir(parents=True)

            recipe = repository.get("a/1")
            prefix = runtime.prefix(recipe)
            prefix.mkdir(parents=True)
            (prefix / "working").write_text("old installation")
            source = root / "source"
            source.mkdir()

            with mock.patch.object(runtime, "fetch", return_value=root / "archive"), \
                    mock.patch.object(runtime, "extract", return_value=source), \
                    mock.patch.object(runtime, "apply_patches"), \
                    mock.patch.object(runtime, "build", side_effect=RuntimeError("failed")):
                with self.assertRaisesRegex(RuntimeError, "failed"):
                    runtime.install_one(recipe)

            self.assertEqual((prefix / "working").read_text(), "old installation")

    def test_parent_upgrade_preserves_installed_descendants(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_recipe(root, "a/1", [])
            self.write_recipe(root, "a/1/b/1", [])
            repository = Repository(root)
            runtime = Runtime(repository)
            stack = root / "stack"
            runtime.cache = stack / "cache"
            runtime.sources = stack / "src"
            runtime.builds = stack / "build"
            runtime.software = stack / "software"
            runtime.modulefiles = stack / "modulefiles"
            runtime.logs = stack / "logs"
            for path in runtime.layout():
                path.mkdir(parents=True)

            parent = repository.get("a/1")
            child = repository.get("a/1/b/1")
            parent_prefix = runtime.prefix(parent)
            child_prefix = runtime.prefix(child)
            self.assertNotIn(parent_prefix, child_prefix.parents)
            child_prefix.mkdir(parents=True)
            (child_prefix / "working").write_text("child installation")
            source = root / "source"
            source.mkdir()

            def build_parent(_recipe, _source):
                parent_prefix.mkdir(parents=True)
                (parent_prefix / "new").write_text("new parent")

            with mock.patch.object(runtime, "fetch", return_value=root / "archive"), \
                    mock.patch.object(runtime, "extract", return_value=source), \
                    mock.patch.object(runtime, "apply_patches"), \
                    mock.patch.object(runtime, "build", side_effect=build_parent), \
                    mock.patch.object(runtime, "test"), \
                    mock.patch.object(runtime, "sync_modulefile"):
                runtime.install_one(parent)

            self.assertEqual((parent_prefix / "new").read_text(), "new parent")
            self.assertEqual((child_prefix / "working").read_text(), "child installation")

    def test_remove_invalidates_dependent_modulefiles(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_recipe(root, "a/1", [])
            self.write_recipe(root, "a/1/b/1", [])
            repository = Repository(root)
            runtime = Runtime(repository)
            runtime.software = root / "software"
            runtime.modulefiles = root / "modulefiles"
            parent = repository.get("a/1")
            child = repository.get("a/1/b/1")
            for recipe in (parent, child):
                modulefile = runtime.modulefile_path(recipe)
                modulefile.parent.mkdir(parents=True, exist_ok=True)
                modulefile.write_text("module")

            runtime.remove(parent)

            self.assertFalse(runtime.modulefile_path(parent).exists())
            self.assertFalse(runtime.modulefile_path(child).exists())

    @staticmethod
    def write_recipe(root: Path, spec: str, dependencies: list[str]):
        parts = spec.split("/")
        name, version = parts[-2:]
        path = root / "packages" / Path(*parts) / "package.toml"
        path.parent.mkdir(parents=True)
        rendered_dependencies = ", ".join(f'"{item}"' for item in dependencies)
        path.write_text(
            f'''schema = 1
[package]
name = "{name}"
version = "{version}"
dependencies = [{rendered_dependencies}]
[source]
url = "https://example.invalid/{name}.tar.gz"
sha256 = "{'0' * 64}"
directory = "{name}-{version}"
[build]
system = "autotools"
'''
        )


class ConfigurationTests(unittest.TestCase):
    def test_user_toml_overrides_defaults(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "config.toml"
            config.write_text(
                '''schema = 1
[paths]
root = "/srv/hpc"
[build]
jobs = 12
profile = "generic"
[mirrors]
gnu = ["https://mirror.example/gnu/"]
'''
            )
            with mock.patch.dict(os.environ, {"TINYHPC_CONFIG": str(config)}, clear=True):
                apply_configuration(REPOSITORY_ROOT)
                self.assertEqual(os.environ["TINYHPC_ROOT"], "/srv/hpc")
                self.assertEqual(os.environ["HPC_SOFTWARE"], "/srv/hpc/software")
                self.assertEqual(os.environ["HPC_JOBS"], "12")
                self.assertEqual(os.environ["HPC_PROFILE"], "generic")
                self.assertEqual(os.environ["HPC_OPT_FLAGS"], "-O3")
                self.assertEqual(os.environ["HPC_OPENBLAS_DYNAMIC_ARCH"], "1")
                self.assertEqual(
                    json.loads(os.environ["HPC_MIRRORS"]),
                    {"gnu": ["https://mirror.example/gnu/"]},
                )

    def test_invalid_mirror_list_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "config.toml"
            config.write_text('schema = 1\n[mirrors]\ngnu = "https://example.invalid/gnu/"\n')
            with mock.patch.dict(os.environ, {"TINYHPC_CONFIG": str(config)}, clear=True):
                with self.assertRaisesRegex(RecipeError, "mirrors.gnu"):
                    apply_configuration(REPOSITORY_ROOT)

    def test_environment_has_precedence_over_toml(self):
        with mock.patch.dict(
            os.environ,
            {"TINYHPC_ROOT": "/scratch/hpc", "HPC_CACHE": "/old-root/cache"},
            clear=True,
        ):
            apply_configuration(REPOSITORY_ROOT)
            self.assertEqual(os.environ["TINYHPC_ROOT"], "/scratch/hpc")
            self.assertEqual(os.environ["HPC_CACHE"], "/scratch/hpc/cache")

    def test_profile_override_recomputes_derived_flags(self):
        with mock.patch.dict(
            os.environ,
            {
                "HPC_PROFILE": "generic",
                "HPC_OPT_FLAGS": "stale native flags",
                "HPC_OPENBLAS_DYNAMIC_ARCH": "0",
            },
            clear=True,
        ):
            apply_configuration(REPOSITORY_ROOT)
            self.assertEqual(os.environ["HPC_OPT_FLAGS"], "-O3")
            self.assertEqual(os.environ["HPC_OPENBLAS_DYNAMIC_ARCH"], "1")

    def test_invalid_profile_override_is_rejected(self):
        with mock.patch.dict(os.environ, {"HPC_PROFILE": "zen4"}, clear=True):
            with self.assertRaisesRegex(RecipeError, "HPC_PROFILE"):
                apply_configuration(REPOSITORY_ROOT)


if __name__ == "__main__":
    unittest.main()
