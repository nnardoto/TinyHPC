# ScaLAPACK 2.2.0

Compatibilidade necessária com CMake 4.x:
- `CMakeLists.txt`: 3.2 -> 3.5
- `scalapack_build.cmake`: 2.8 -> 3.5
- `BLACS/INSTALL/CMakeLists.txt`: 2.8 -> 3.5

Na receita definitiva isso deve virar patch versionado.
OpenBLAS precisa exportar `xerbla_`.
