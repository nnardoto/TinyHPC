# ScaLAPACK 2.2.0 (GCC 9 / OpenMPI 5 / OpenBLAS 0.3.30)

Recipe for the TinyHPC validated stack.

- compiler: GCC 9.5.0
- MPI: OpenMPI 5.0.8
- BLAS/LAPACK: OpenBLAS 0.3.30 (LP64)
- ScaLAPACK: 2.2.0 (LP64)
- build system: CMake
- shared library: enabled
- upstream ScaLAPACK test suite: disabled during the package build
- TinyHPC smoke test: BLACS process-grid initialization with two MPI ranks

The BLAS and LAPACK paths are passed explicitly to CMake. This avoids accidental
selection of system BLAS/LAPACK and the duplicate/incorrect link lines seen in
manual builds.
