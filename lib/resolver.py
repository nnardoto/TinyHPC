#!/usr/bin/env python3
"""Deterministic CLI spec resolution for TinyHPC."""

from __future__ import annotations

import os
from pathlib import Path


class ResolutionError(RuntimeError):
    pass


def compiler_state_path() -> Path:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return config_home / "tinyhpc" / "compiler"


def read_compiler() -> str | None:
    path = compiler_state_path()
    try:
        if not path.is_file():
            return None
        value = path.read_text().strip()
    except (OSError, UnicodeError) as exc:
        raise ResolutionError(f"não foi possível ler o contexto de compilador: {exc}") from exc
    return value or None


def write_compiler(spec: str) -> None:
    path = compiler_state_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(spec + "\n")
    except OSError as exc:
        raise ResolutionError(f"não foi possível salvar o contexto de compilador: {exc}") from exc


def clear_compiler() -> None:
    try:
        compiler_state_path().unlink(missing_ok=True)
    except OSError as exc:
        raise ResolutionError(f"não foi possível remover o contexto de compilador: {exc}") from exc


class Resolver:
    def __init__(self, repository: object):
        self.repository = repository
        self.compilers = sorted(
            spec
            for spec, recipe in repository.recipes.items()
            if recipe.module.get("family") == "compiler"
        )

    @staticmethod
    def _parts(spec: str) -> list[str]:
        normalized = spec.strip("/")
        if not normalized:
            return []
        parts = normalized.split("/")
        return [] if "" in parts else parts

    @classmethod
    def _suffix_matches(cls, query: str, canonical: str) -> bool:
        query_parts = cls._parts(query)
        canonical_parts = cls._parts(canonical)
        if not query_parts:
            return False
        if len(query_parts) % 2 == 0:
            return canonical_parts[-len(query_parts) :] == query_parts

        if len(canonical_parts) < 2 or canonical_parts[-2] != query_parts[-1]:
            return False
        prefix = query_parts[:-1]
        return not prefix or canonical_parts[:-2][-len(prefix) :] == prefix

    def _matches(self, query: str, specs: list[str]) -> list[str]:
        return [spec for spec in specs if self._suffix_matches(query, spec)]

    @staticmethod
    def _render_matches(matches: list[str]) -> str:
        return "\n".join(f"  {match}" for match in matches)

    def list_compilers(self) -> list[str]:
        return list(self.compilers)

    def validate_compiler_context(self, compiler_context: str | None) -> str | None:
        if compiler_context and compiler_context not in self.compilers:
            raise ResolutionError(
                f"contexto de compilador indisponível: {compiler_context}\n"
                "use 'hpc compiler --clear' ou selecione outro compilador"
            )
        return compiler_context

    def resolve_compiler(self, query: str) -> str:
        normalized = query.strip("/")
        if normalized in self.compilers:
            return normalized

        matches = self._matches(query, self.compilers)
        if len(matches) == 1:
            return matches[0]
        if not matches:
            raise ResolutionError(f"compilador não encontrado: {query}")
        raise ResolutionError(
            f"compilador ambíguo: '{query}'\n\n"
            f"correspondências:\n{self._render_matches(matches)}"
        )

    def resolve(self, query: str, compiler_context: str | None = None) -> str:
        normalized = query.strip("/")
        if normalized in self.repository.recipes:
            return normalized

        compiler_context = self.validate_compiler_context(compiler_context)

        specs = sorted(self.repository.recipes)
        if compiler_context:
            prefix = compiler_context.rstrip("/") + "/"
            specs = [
                spec
                for spec in specs
                if spec == compiler_context or spec.startswith(prefix)
            ]

        matches = self._matches(query, specs)
        if len(matches) == 1:
            return matches[0]
        if not matches:
            if compiler_context:
                raise ResolutionError(
                    f"spec não encontrada sob o compilador {compiler_context}:\n  {query}"
                )
            raise ResolutionError(f"spec não encontrada: {query}")

        context = (
            f"\ncontexto de compilador: {compiler_context}" if compiler_context else ""
        )
        guidance = (
            ""
            if compiler_context
            else "\n\nuse uma spec mais longa ou selecione um contexto de compilador"
        )
        raise ResolutionError(
            f"spec ambígua: '{query}'{context}\n\n"
            f"correspondências:\n{self._render_matches(matches)}{guidance}"
        )
