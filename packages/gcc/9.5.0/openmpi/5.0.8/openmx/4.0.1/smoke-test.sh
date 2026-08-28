#!/usr/bin/env bash
set -euo pipefail

dependencies="$(LC_ALL=C ldd "${HPC_PREFIX}/bin/openmx")"
if [[ "${dependencies}" == *"not found"* ]]; then
  printf '%s\n' "${dependencies}" >&2
  exit 1
fi

work_dir="$(mktemp -d "${HPC_PREFIX}/.smoke-test.XXXXXX")"
trap 'rm -rf "${work_dir}"' EXIT
cp "${HPC_PREFIX}/work/Methane.dat" "${work_dir}/"
output="$({
  cd "${work_dir}"
  "${HPC_PREFIX}/bin/openmx" Methane.dat -nt 1
})"
printf '%s\n' "${output}"
if [[ "${output}" != *"The calculation was normally finished."* ]]; then
  printf 'calculo de teste nao terminou normalmente\n' >&2
  exit 1
fi
