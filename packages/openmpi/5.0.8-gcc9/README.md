# OpenMPI 5.0.8 + GCC 9.5.0

Receita reproduzível baseada na instalação manual validada.

## Dependência

- `gcc/9.5.0`

O comando `hpc install openmpi/5.0.8-gcc9` instala a dependência automaticamente quando necessário e carrega seu modulefile durante o build e os testes.

## Configuração validada

```text
CC=gcc CXX=g++ FC=gfortran
--disable-mpi-fortran-usempif08
```

Prefixo:

```text
/opt/hpc/software/openmpi/5.0.8-gcc9
```

## Integridade

Fonte oficial Open MPI, tarball `openmpi-5.0.8.tar.bz2`, com SHA-256 travado no `package.conf`.

## Testes

A receita verifica:

- `mpirun`, `mpicc` e `mpifort` instalados;
- versão 5.0.8;
- wrappers ligados a GCC/GFortran;
- compilação de um programa MPI em C;
- execução local com dois ranks.

## Patches

Patches específicos da versão podem ser colocados em `patches/*.patch`; o framework os aplica em ordem lexicográfica antes do configure.

## Receita legada

A implementação legada permanece disponível para auxiliar a migração:

- `build.sh`
- `test.sh`

O novo CLI usa a receita hierárquica `gcc/9.5.0/openmpi/5.0.8/package.toml`. Os scripts deste diretório não são descobertos automaticamente.
