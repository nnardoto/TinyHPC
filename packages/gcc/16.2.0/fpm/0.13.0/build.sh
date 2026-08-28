#!/usr/bin/env bash
set -euo pipefail

source_file="${HPC_SRC}/fpm-0.13.0/fpm-0.13.0.F90"
build_dir="${HPC_BUILD}/gcc/16.2.0/fpm/0.13.0"
mkdir -p "${build_dir}/modules" "${HPC_PREFIX}/bin"

"${GCC_ROOT}/bin/gfortran" \
  ${HPC_OPT_FLAGS} \
  -J "${build_dir}/modules" \
  "${source_file}" \
  -Wl,-rpath,"${GCC_ROOT}/lib64" \
  -Wl,-rpath,"${GCC_ROOT}/lib" \
  -o "${build_dir}/fpm"

install -m 0755 "${build_dir}/fpm" "${HPC_PREFIX}/bin/fpm"
