#!/usr/bin/env bash
set -euo pipefail

temporary="$(mktemp -d)"
trap 'rm -rf "${temporary}"' EXIT

for entry in "pw.x:Program PWSCF" "ph.x:Program PHONON"; do
  executable="${entry%%:*}"
  banner="${entry#*:}"
  dependencies="$(LC_ALL=C ldd "${HPC_PREFIX}/bin/${executable}")"
  if [[ "${dependencies}" == *"not found"* ]]; then
    printf '%s\n' "${dependencies}" >&2
    exit 1
  fi
  output="$({
    cd "${temporary}"
    "${HPC_PREFIX}/bin/${executable}" </dev/null 2>&1 || true
  })"
  if [[ "${output}" != *"${banner}"* ]]; then
    printf '%s\n' "${output}" >&2
    exit 1
  fi
done
