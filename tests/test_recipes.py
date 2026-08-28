from pathlib import Path
import os
import sys
import tempfile
import unittest
from unittest import mock


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPOSITORY_ROOT / "lib"))

from recipe import RecipeError, Repository, Runtime, apply_configuration  # noqa: E402


QE_SPEC = "gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6"


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
                "gcc/9.5.0",
                "gcc/9.5.0/openmpi/5.0.8",
                "gcc/9.5.0/openblas/0.3.30",
                "gcc/9.5.0/fftw/3.3.10",
                "gcc/9.5.0/openmpi/5.0.8/scalapack/2.2.0",
                QE_SPEC,
            ],
        )

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
        self.assertIn('setenv("CC", pathJoin(root, "bin/gcc"))', modulefile)


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

    @staticmethod
    def write_recipe(root: Path, spec: str, dependencies: list[str]):
        name, version = spec.split("/")
        path = root / "packages" / name / version / "package.toml"
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
profile = "zen4"
'''
            )
            with mock.patch.dict(os.environ, {"TINYHPC_CONFIG": str(config)}, clear=True):
                apply_configuration(REPOSITORY_ROOT)
                self.assertEqual(os.environ["TINYHPC_ROOT"], "/srv/hpc")
                self.assertEqual(os.environ["HPC_SOFTWARE"], "/srv/hpc/software")
                self.assertEqual(os.environ["HPC_JOBS"], "12")
                self.assertEqual(os.environ["HPC_PROFILE"], "zen4")

    def test_environment_has_precedence_over_toml(self):
        with mock.patch.dict(
            os.environ,
            {"TINYHPC_ROOT": "/scratch/hpc", "HPC_CACHE": "/old-root/cache"},
            clear=True,
        ):
            apply_configuration(REPOSITORY_ROOT)
            self.assertEqual(os.environ["TINYHPC_ROOT"], "/scratch/hpc")
            self.assertEqual(os.environ["HPC_CACHE"], "/scratch/hpc/cache")


if __name__ == "__main__":
    unittest.main()
