from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "hpc"
sys.path.insert(0, str(ROOT / "lib"))

from recipe import Repository, Runtime  # noqa: E402


QE_SPEC = "gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6"
CONFIG_ENVIRONMENT = (
    "TINYHPC_CONFIG",
    "TINYHPC_HOME",
    "TINYHPC_ROOT",
    "HPC_JOBS",
    "HPC_PROFILE",
    "HPC_OPT_FLAGS",
    "HPC_OPENBLAS_DYNAMIC_ARCH",
    "HPC_MIRRORS",
    "HPC_ROOT",
    "HPC_CACHE",
    "HPC_SRC",
    "HPC_BUILD",
    "HPC_SOFTWARE",
    "HPC_MODULEFILES",
    "HPC_LOGS",
)


class BashCliTests(unittest.TestCase):
    def run_cli_process(self, *arguments: str, environment=None) -> subprocess.CompletedProcess:
        configured_environment = dict(os.environ)
        for variable in CONFIG_ENVIRONMENT:
            configured_environment.pop(variable, None)
        configured_environment["XDG_CONFIG_HOME"] = str(ROOT / "tests/.config-empty")
        configured_environment["PYTHONDONTWRITEBYTECODE"] = "1"
        if environment:
            configured_environment.update(environment)
        result = subprocess.run(
            ["bash", str(CLI), *arguments],
            cwd=ROOT,
            env=configured_environment,
            stdin=subprocess.DEVNULL,
            check=False,
            text=True,
            capture_output=True,
            timeout=30,
        )
        return result

    def run_cli(self, *arguments: str, environment=None) -> str:
        result = self.run_cli_process(*arguments, environment=environment)
        result.check_returncode()
        return result.stdout

    def test_help_is_successful_and_does_not_load_configuration(self):
        result = self.run_cli_process(
            "--help", environment={"TINYHPC_CONFIG": "/does/not/exist.toml"}
        )

        self.assertEqual(result.returncode, 0)
        self.assertIn("Uso: hpc <comando> [opções]", result.stdout)
        self.assertIn("installed", result.stdout)
        self.assertEqual(result.stderr, "")

    def test_installed_lists_only_valid_installations(self):
        with tempfile.TemporaryDirectory() as temporary:
            stack = Path(temporary)
            repository = Repository(ROOT)
            runtime = Runtime(repository)
            runtime.software = stack / "software"
            valid = repository.get("gmp/6.1.0")
            stale = repository.get("mpfr/4.1.0")
            for recipe, fingerprint in (
                (valid, runtime.recipe_fingerprint(valid)),
                (stale, "stale"),
            ):
                marker = runtime.marker_path(recipe)
                marker.parent.mkdir(parents=True)
                marker.write_text(
                    json.dumps(
                        {"schema": 2, "spec": recipe.spec, "fingerprint": fingerprint}
                    )
                )

            output = self.run_cli(
                "installed", environment={"TINYHPC_ROOT": str(stack)}
            )

        self.assertEqual(output.splitlines(), [valid.spec])

    def test_bash_interface_registers_command_completion(self):
        result = subprocess.run(
            [
                "bash",
                "-c",
                "source shell/init.bash 2>/dev/null; "
                "COMP_WORDS=(hpc ins); COMP_CWORD=1; _tinyhpc_complete; "
                "printf '%s\\n' \"${COMPREPLY[@]}\"; complete -p hpc",
            ],
            cwd=ROOT,
            check=True,
            text=True,
            capture_output=True,
        )
        self.assertIn("installed", result.stdout.splitlines())
        self.assertIn("complete -F _tinyhpc_complete hpc", result.stdout)

        help_result = subprocess.run(
            [
                "bash",
                "-c",
                "source shell/init.bash 2>/dev/null; "
                "COMP_WORDS=(hpc -); COMP_CWORD=1; _tinyhpc_complete; "
                "printf '%s\\n' \"${COMPREPLY[@]}\"",
            ],
            cwd=ROOT,
            check=True,
            text=True,
            capture_output=True,
        )
        self.assertEqual(help_result.stdout.splitlines(), ["-h", "--help"])

    def test_quantum_espresso_plan_through_bash(self):
        plan = self.run_cli("plan", QE_SPEC).splitlines()
        self.assertEqual(plan[-1], QE_SPEC)
        self.assertIn("gcc/9.5.0/openmpi/5.0.8", plan)

    def test_user_configuration_through_bash(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "config.toml"
            config.write_text(
                '''schema = 1
[paths]
root = "/cluster/tinyhpc"
[build]
jobs = 24
'''
            )
            output = self.run_cli("config", environment={"TINYHPC_CONFIG": str(config)})
            self.assertIn("TINYHPC_ROOT=/cluster/tinyhpc", output)
            self.assertIn("HPC_JOBS=24", output)
            self.assertIn("HPC_LOGS=/cluster/tinyhpc/logs", output)

    def test_compilers_lists_available_compilers_without_selection(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = self.run_cli(
                "compilers", environment={"XDG_CONFIG_HOME": temporary}
            )
        self.assertIn("  gcc/9.5.0", output)
        self.assertIn("  gcc/16.2.0", output)
        self.assertNotIn("* ", output)

    def test_compiler_set_show_and_resolve_use_persisted_context(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = {"XDG_CONFIG_HOME": temporary}
            selected = self.run_cli("compiler", "gcc/16.2.0", environment=environment)
            current = self.run_cli("compiler", environment=environment)
            compilers = self.run_cli("compilers", environment=environment)
            resolved = self.run_cli(
                "resolve", "quantum-espresso/7.6", environment=environment
            )
            verbose = self.run_cli(
                "resolve", "-v", "quantum-espresso/7.6", environment=environment
            )

        self.assertEqual(selected.strip(), "gcc/16.2.0")
        self.assertEqual(current.strip(), "gcc/16.2.0")
        self.assertIn("* gcc/16.2.0", compilers)
        self.assertEqual(resolved.strip(), "gcc/16.2.0/openmpi/5.0.8/quantum-espresso/7.6")
        self.assertIn("query:    quantum-espresso/7.6", verbose)
        self.assertIn("compiler: gcc/16.2.0", verbose)
        self.assertIn("resolved: gcc/16.2.0/openmpi/5.0.8/quantum-espresso/7.6", verbose)

    def test_compiler_clear_removes_context(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = {"XDG_CONFIG_HOME": temporary}
            self.run_cli("compiler", "gcc/16.2.0", environment=environment)
            self.run_cli("compiler", "--clear", environment=environment)
            current = self.run_cli("compiler", environment=environment)
            compilers = self.run_cli("compilers", environment=environment)

        self.assertEqual(current, "")
        self.assertNotIn("* ", compilers)

    def test_compiler_name_with_multiple_versions_is_ambiguous(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = self.run_cli_process(
                "compiler", "gcc", environment={"XDG_CONFIG_HOME": temporary}
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("compilador ambíguo: 'gcc'", result.stderr)
        self.assertIn("gcc/9.5.0", result.stderr)
        self.assertIn("gcc/16.2.0", result.stderr)

    def test_unknown_short_spec_fails_without_fuzzy_matching(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = self.run_cli_process(
                "resolve", "quantum", environment={"XDG_CONFIG_HOME": temporary}
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("spec não encontrada: quantum", result.stderr)

    def test_short_spec_is_ambiguous_without_compiler_context(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = self.run_cli_process(
                "resolve",
                "quantum-espresso/7.6",
                environment={"XDG_CONFIG_HOME": temporary},
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("spec ambígua: 'quantum-espresso/7.6'", result.stderr)
        self.assertIn("gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6", result.stderr)
        self.assertIn("gcc/16.2.0/openmpi/5.0.8/quantum-espresso/7.6", result.stderr)

    def test_compiler_and_install_reject_extra_arguments(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = {"XDG_CONFIG_HOME": temporary}
            compiler = self.run_cli_process(
                "compiler", "gcc/16.2.0", "extra", environment=environment
            )
            install = self.run_cli_process(
                "install", QE_SPEC, "extra", environment=environment
            )
        self.assertNotEqual(compiler.returncode, 0)
        self.assertIn("uso: hpc compiler", compiler.stderr)
        self.assertNotEqual(install.returncode, 0)
        self.assertIn("uso: hpc install", install.stderr)

    def test_stale_compiler_context_fails_before_short_resolution(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = Path(temporary) / "tinyhpc/compiler"
            state.parent.mkdir(parents=True)
            state.write_text("gcc/99.0\n")
            result = self.run_cli_process(
                "resolve", "isl", environment={"XDG_CONFIG_HOME": temporary}
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("contexto de compilador indisponível: gcc/99.0", result.stderr)

    def test_fish_exists_only_as_user_interface(self):
        fish_files = [path.relative_to(ROOT).as_posix() for path in ROOT.glob("**/*.fish")]
        self.assertEqual(fish_files, ["shell/init.fish"])
        self.assertTrue((ROOT / "bin/hpc").read_text().startswith("#!/usr/bin/env bash"))

    def test_environment_can_be_rendered_for_all_shells(self):
        bash_environment = self.run_cli("env", "--shell", "bash")
        zsh_environment = self.run_cli("env", "--shell", "zsh")
        fish_environment = self.run_cli("env", "--shell", "fish")
        self.assertIn("export TINYHPC_ROOT=", bash_environment)
        self.assertIn("export TINYHPC_ROOT=", zsh_environment)
        self.assertIn("set -gx TINYHPC_ROOT ", fish_environment)

    def test_cli_resolves_repository_through_symlink(self):
        with tempfile.TemporaryDirectory() as temporary:
            link = Path(temporary) / "hpc"
            link.symlink_to(CLI)
            result = subprocess.run(
                [str(link), "plan", QE_SPEC],
                cwd=ROOT,
                env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
                check=True,
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.stdout.splitlines()[-1], QE_SPEC)

    def test_doctor_initializes_lmod_inside_cli(self):
        with tempfile.TemporaryDirectory() as temporary:
            temporary_path = Path(temporary)
            root = temporary_path / "root"
            for name in ("cache", "src", "build", "software", "modulefiles", "logs"):
                (root / name).mkdir(parents=True, exist_ok=True)

            config = temporary_path / "config.toml"
            config.write_text(
                "schema = 1\n"
                "[paths]\n"
                f'root = "{root}"\n'
                "[build]\n"
                "jobs = 4\n"
            )
            lmod_init = temporary_path / "lmod-init.bash"
            lmod_init.write_text("module() { return 0; }\n")

            output = self.run_cli(
                "doctor",
                environment={
                    "TINYHPC_CONFIG": str(config),
                    "TINYHPC_LMOD_INIT": str(lmod_init),
                },
            )
            self.assertIn("module       OK", output)

    def test_install_plan_is_not_consumed_by_child_stdin(self):
        with tempfile.TemporaryDirectory() as temporary:
            temporary_path = Path(temporary)
            root = temporary_path / "root"
            for name in ("cache", "src", "build", "software", "modulefiles", "logs"):
                (root / name).mkdir(parents=True, exist_ok=True)

            calls = temporary_path / "calls"
            plan_calls = temporary_path / "plan-calls"
            fake_bin = temporary_path / "bin"
            fake_bin.mkdir()
            fake_python = fake_bin / "python3.13"
            fake_python.write_text(
                f'''#!/usr/bin/env bash
if [[ "${{1:-}}" == "-c" ]]; then exit 0; fi
for argument in "$@"; do
  case "$argument" in
    environment|resolve|plan|installed|dependencies|install-one) command="$argument"; break ;;
  esac
done
case "${{command:-}}" in
  environment)
    printf '%s\t%s\n' TINYHPC_HOME {ROOT} TINYHPC_ROOT {root} HPC_JOBS 1 HPC_PROFILE generic \
      HPC_ROOT {root} HPC_CACHE {root}/cache HPC_SRC {root}/src HPC_BUILD {root}/build \
      HPC_SOFTWARE {root}/software HPC_MODULEFILES {root}/modulefiles HPC_LOGS {root}/logs
    ;;
  resolve) printf 'target/1\n' ;;
  plan)
    printf '%s\n' "${{@: -1}}" >> {plan_calls}
    printf 'dependency/1\ntarget/1\n'
    ;;
  installed) exit 1 ;;
  dependencies) : ;;
  install-one)
    printf '%s\n' "${{@: -1}}" >> {calls}
    IFS= read -r ignored || true
    ;;
esac
'''
            )
            fake_python.chmod(0o755)
            bash_environment = temporary_path / "bash-env"
            bash_environment.write_text("module() { return 0; }\n")

            self.run_cli(
                "install",
                "short",
                environment={
                    "BASH_ENV": str(bash_environment),
                    "PATH": f"{fake_bin}:{os.environ['PATH']}",
                },
            )

            self.assertEqual(calls.read_text().splitlines(), ["dependency/1", "target/1"])
            self.assertEqual(plan_calls.read_text().splitlines(), ["target/1"])

    def test_bash_interface_is_sourceable(self):
        result = subprocess.run(
            [
                "bash",
                "-c",
                'unset TINYHPC_CONFIG TINYHPC_ROOT; source shell/init.bash 2>/dev/null; printf "%s" "$TINYHPC_ROOT"',
            ],
            cwd=ROOT,
            check=True,
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.stdout, "/opt/hpc")

    def test_bootstrap_supports_unprivileged_clean_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            temporary_path = Path(temporary) / "installation with spaces"
            home = temporary_path / "home"
            home.mkdir(parents=True)
            manager = temporary_path / "opt/tinyhpc"
            stack = temporary_path / "opt/hpc"
            cli = temporary_path / "bin/hpc"
            bash_environment = temporary_path / "bash-env"
            bash_environment.write_text(
                'module() { [[ "${1:-}" == "--version" ]] && printf "mock Lmod\\n"; return 0; }\n'
            )
            environment = {
                key: value
                for key, value in os.environ.items()
                if key not in CONFIG_ENVIRONMENT
            }
            environment.update(
                {
                    "BASH_ENV": str(bash_environment),
                    "HOME": str(home),
                    "USER": os.environ.get("USER", "nobody"),
                    "XDG_CONFIG_HOME": str(home / ".config"),
                    "TINYHPC_HOME": str(manager),
                    "TINYHPC_ROOT": str(stack),
                    "TINYHPC_BIN": str(cli),
                    "TINYHPC_SUDO": "",
                    "PYTHONDONTWRITEBYTECODE": "1",
                }
            )

            subprocess.run(
                ["bash", str(ROOT / "bootstrap.sh")],
                cwd=ROOT,
                env=environment,
                check=True,
                text=True,
                capture_output=True,
            )

            self.assertTrue(cli.is_symlink())
            self.assertTrue((stack / "modulefiles").is_dir())
            config = home / ".config/tinyhpc/config.toml"
            self.assertTrue(config.is_file())
            output = subprocess.run(
                [str(cli), "config"],
                env={**environment, "TINYHPC_CONFIG": str(config)},
                check=True,
                text=True,
                capture_output=True,
            ).stdout
            self.assertIn(f"TINYHPC_ROOT={stack}", output)
            packages = subprocess.run(
                [str(cli), "list"],
                env={**environment, "TINYHPC_CONFIG": str(config)},
                check=True,
                text=True,
                capture_output=True,
            ).stdout
            self.assertIn("gcc/9.5.0", packages)


if __name__ == "__main__":
    unittest.main()
