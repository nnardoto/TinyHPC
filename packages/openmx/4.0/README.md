# OpenMX 4.0 + patch 4.0.1

Stack validada:
GCC 9.5.0 + OpenMPI 5.0.8 + OpenBLAS 0.3.30 + FFTW 3.3.10 + ScaLAPACK 2.2.0.

Makefile validado:

```make
CC = mpicc -O3 -march=native -fopenmp -fcommon -I${FFTW_HOME}/include
FC = mpifort -O3 -march=native -fopenmp
LIB = -L${SCALAPACK_HOME}/lib -lscalapack       -L${OPENBLAS_HOME}/lib -lopenblas       -L${FFTW_HOME}/lib -lfftw3 -lfftw3_omp       -L${MPI_HOME}/lib       -lmpi_usempif08 -lmpi_usempi_ignore_tkr -lmpi_mpifh -lmpi       -lgfortran -lpthread -lm -ldl
```

A linkedição MPI-Fortran explícita é necessária por causa de `elpa1.o`/`mpi_allreduce_`.
