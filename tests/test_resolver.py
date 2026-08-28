from pathlib import Path
import os
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPOSITORY_ROOT / "lib"))

from resolver import (  # noqa: E402
    ResolutionError,
    Resolver,
    clear_compiler,
    compiler_state_path,
    read_compiler,
    write_compiler,
)


GCC9 = "gcc/9.5.0"
GCC16 = "gcc/16.2.0"
GCC9_QE = f"{GCC9}/openmpi/5.0.8/quantum-espresso/7.6"
GCC16_QE = f"{GCC16}/openmpi/5.0.8/quantum-espresso/7.6"
GCC16_MPI509_QE = f"{GCC16}/openmpi/5.0.9/quantum-espresso/7.6"


class ResolverTests(unittest.TestCase):
    def setUp(self):
        specs = {
            "isl/0.24": None,
            "zlib/1.3.1": None,
            GCC9: "compiler",
            GCC16: "compiler",
            f"{GCC9}/openmpi/5.0.8": "mpi",
            GCC9_QE: None,
            f"{GCC16}/openmpi/5.0.8": "mpi",
            GCC16_QE: None,
            f"{GCC16}/openmpi/5.0.9": "mpi",
            GCC16_MPI509_QE: None,
        }
        recipes = {
            spec: SimpleNamespace(module={"family": family} if family else {})
            for spec, family in specs.items()
        }
        self.resolver = Resolver(SimpleNamespace(recipes=recipes))

    def test_canonical_spec_resolves_directly_even_outside_context(self):
        self.assertEqual(self.resolver.resolve(GCC16_QE, compiler_context=GCC9), GCC16_QE)

    def test_unique_name_resolves(self):
        self.assertEqual(self.resolver.resolve("isl"), "isl/0.24")

    def test_unique_name_and_version_resolve(self):
        self.assertEqual(self.resolver.resolve("zlib/1.3.1"), "zlib/1.3.1")

    def test_unique_structural_suffix_resolves(self):
        self.assertEqual(
            self.resolver.resolve("openmpi/5.0.9/quantum-espresso/7.6"),
            GCC16_MPI509_QE,
        )

    def test_global_ambiguity_lists_every_match(self):
        with self.assertRaises(ResolutionError) as raised:
            self.resolver.resolve("quantum-espresso/7.6")
        message = str(raised.exception)
        self.assertIn("spec ambígua", message)
        self.assertIn(GCC9_QE, message)
        self.assertIn(GCC16_QE, message)
        self.assertIn(GCC16_MPI509_QE, message)

    def test_compiler_context_removes_global_ambiguity(self):
        self.assertEqual(
            self.resolver.resolve("quantum-espresso/7.6", compiler_context=GCC9),
            GCC9_QE,
        )

    def test_compiler_context_does_not_remove_remaining_ambiguity(self):
        with self.assertRaisesRegex(ResolutionError, "contexto de compilador: gcc/16.2.0"):
            self.resolver.resolve("quantum-espresso/7.6", compiler_context=GCC16)

    def test_compiler_context_has_no_global_fallback(self):
        with self.assertRaisesRegex(ResolutionError, "sob o compilador gcc/16.2.0"):
            self.resolver.resolve("isl", compiler_context=GCC16)

    def test_compilers_are_selected_by_module_family(self):
        self.assertEqual(self.resolver.list_compilers(), [GCC16, GCC9])

    def test_compiler_name_is_ambiguous_without_version(self):
        with self.assertRaises(ResolutionError) as raised:
            self.resolver.resolve_compiler("gcc")
        message = str(raised.exception)
        self.assertIn("compilador ambíguo", message)
        self.assertIn(GCC9, message)
        self.assertIn(GCC16, message)

    def test_compiler_resolution_never_selects_highest_version(self):
        with self.assertRaises(ResolutionError):
            self.resolver.resolve_compiler("gcc")

    def test_unknown_query_is_not_found(self):
        with self.assertRaisesRegex(ResolutionError, "spec não encontrada: quantum"):
            self.resolver.resolve("quantum")

    def test_empty_path_components_are_not_accepted(self):
        with self.assertRaises(ResolutionError):
            self.resolver.resolve("isl//0.24")
        with self.assertRaises(ResolutionError):
            self.resolver.resolve_compiler("gcc//16.2.0")

    def test_stale_compiler_context_fails_explicitly(self):
        with self.assertRaisesRegex(ResolutionError, "contexto de compilador indisponível"):
            self.resolver.resolve("isl", compiler_context="gcc/99.0")

    def test_compiler_context_persists_and_clears(self):
        with tempfile.TemporaryDirectory() as temporary, mock.patch.dict(
            os.environ, {"XDG_CONFIG_HOME": temporary}
        ):
            self.assertIsNone(read_compiler())
            write_compiler(GCC16)
            self.assertEqual(read_compiler(), GCC16)
            clear_compiler()
            self.assertIsNone(read_compiler())

    def test_empty_xdg_config_home_uses_default_directory(self):
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": ""}):
            self.assertEqual(
                compiler_state_path(), Path.home() / ".config/tinyhpc/compiler"
            )

    def test_corrupt_compiler_context_has_a_domain_error(self):
        with tempfile.TemporaryDirectory() as temporary, mock.patch.dict(
            os.environ, {"XDG_CONFIG_HOME": temporary}
        ):
            path = compiler_state_path()
            path.parent.mkdir(parents=True)
            path.write_bytes(b"\xff")
            with self.assertRaisesRegex(ResolutionError, "não foi possível ler"):
                read_compiler()


if __name__ == "__main__":
    unittest.main()
