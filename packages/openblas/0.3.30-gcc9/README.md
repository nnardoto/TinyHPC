# OpenBLAS 0.3.30 + GCC 9.5.0

Usar release estável, não `develop`.

Flags validadas:

```text
CC=gcc FC=gfortran NOFORTRAN=0 NO_LAPACK=0 ONLY_CBLAS=0
INTERFACE64=0 USE_OPENMP=1 DYNAMIC_ARCH=1
```

Teste obrigatório após instalar:

```text
nm -D libopenblas.so | grep xerbla_
nm -D libopenblas.so | grep dgesv_
```
