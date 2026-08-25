# OpenBLAS 0.3.30 + GCC 9.5.0

Receita reproduzível do TinyHPC para BLAS/LAPACK.

## Dependência

- `gcc/9.5.0`

## Build

- `DYNAMIC_ARCH=1`: binário não fica preso à CPU da máquina de build;
- threading pthread padrão (`USE_THREAD=1`, `USE_OPENMP=0`);
- `NO_AFFINITY=1`: o escalonamento fica sob controle do usuário/SLURM;
- interface LP64 padrão;
- rpath para os runtimes do GCC 9 incorporado na biblioteca, sem poluir o shell com o `LD_LIBRARY_PATH` do GCC.

Prefixo:

```text
/opt/hpc/software/openblas/0.3.30-gcc9
```

## Teste

A receita compila e executa um programa Fortran que valida:

- `DGEMM` (BLAS);
- `DGESV` (LAPACK).

## Integridade

O tarball oficial `OpenBLAS-0.3.30.tar.gz` usa SHA-256 travado no `package.conf`.
