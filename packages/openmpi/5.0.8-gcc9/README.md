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

## Compatibilidade Bash

A receita também possui implementações equivalentes em Bash:

- `build.sh`
- `test.sh`

O CLI continua usando Fish por padrão. Para validar/usar a variante Bash:

```fish
set -lx HPC_RECIPE_SHELL bash
hpc install openmpi/5.0.8-gcc9
```

ou, a partir de Bash:

```bash
HPC_RECIPE_SHELL=bash hpc install openmpi/5.0.8-gcc9
```

Os dois caminhos usam o mesmo `package.conf`, checksum, patches, prefixo e modulefile. A intenção é que apenas a implementação da receita varie, nunca os metadados do pacote.
