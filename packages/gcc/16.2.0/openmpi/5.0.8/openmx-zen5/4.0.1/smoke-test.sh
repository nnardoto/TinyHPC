#!/usr/bin/env bash
set -euo pipefail

cpu_flags="$(LC_ALL=C lscpu | awk -F: '/^Flags:/ {print $2}')"
for required_flag in avx512f avx512dq avx512bw avx512vl; do
  if [[ " ${cpu_flags} " != *" ${required_flag} "* ]]; then
    printf 'CPU de destino sem a extensão obrigatória: %s\n' "${required_flag}" >&2
    exit 1
  fi
done

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
