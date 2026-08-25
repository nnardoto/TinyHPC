# TinyHPC

**TinyHPC — minimal tooling for reproducible HPC.**

TinyHPC é um gerenciador pessoal, pequeno e reproduzível para stacks HPC. O CLI é escrito em Fish, usa Lmod para ambientes e mantém receitas versionadas com checksums, patches, testes e modulefiles. Receitas Bash podem ser fornecidas como caminho de compatibilidade.

## Arquitetura

O projeto separa deliberadamente a ferramenta da stack que ela administra:

```text
~/src/TinyHPC/        # clone Git / desenvolvimento
        │
        └── bootstrap
              ↓
/opt/tinyhpc/         # instalação do gerenciador
/usr/local/bin/hpc    # CLI

/opt/hpc/             # stack gerenciada
├── cache/
├── src/
├── build/
├── software/
├── modulefiles/
└── logs/
```

As duas raízes são configuráveis:

```text
TINYHPC_HOME=/opt/tinyhpc
TINYHPC_ROOT=/opt/hpc
```

As receitas não devem depender diretamente desses caminhos padrão.

## Bootstrap

### Fish (principal)

```fish
./bootstrap.fish
source ~/.config/fish/conf.d/tinyhpc.fish
hpc doctor
```

### Bash

```bash
./bootstrap.sh
source ~/.config/tinyhpc/bashrc
hpc doctor
```

O bootstrap é idempotente e:

- detecta ou instala Lmod;
- no bootstrap Bash, instala Fish se necessário, pois `hpc` usa Fish;
- instala uma cópia do TinyHPC em `/opt/tinyhpc`;
- cria `/usr/local/bin/hpc` apontando para `/opt/tinyhpc/bin/hpc`;
- cria a árvore gerenciada em `/opt/hpc`;
- adiciona `/opt/hpc/modulefiles` ao Lmod;
- grava `TINYHPC_HOME` e `TINYHPC_ROOT` no ambiente do usuário.

Gerenciadores de pacotes detectados atualmente: `pacman`, `apt-get`, `dnf` e `zypper`.

Para usar outros prefixos desde o primeiro bootstrap:

```bash
TINYHPC_HOME="$HOME/.local/opt/tinyhpc" \
TINYHPC_ROOT="$HOME/.local/hpc" \
./bootstrap.sh
```

> O symlink global em `/usr/local/bin/hpc` ainda requer privilégio administrativo.

## Comandos

```text
hpc list
hpc info <spec>
hpc install <spec>
hpc clean <spec>
hpc remove <spec>
hpc doctor
```

Exemplo:

```fish
hpc info openmpi/5.0.8-gcc9
hpc install openmpi/5.0.8-gcc9
module load openmpi/5.0.8-gcc9
mpirun --version
```

`openmpi/5.0.8-gcc9` declara `gcc/9.5.0` como dependência. O GCC, por sua vez, declara seus pré-requisitos matemáticos como receitas normais:

```text
gmp/6.1.0
   ├──> mpfr/4.1.0
   └────────────┐
                ├──> mpc/1.2.1
mpfr/4.1.0 ─────┘

(gmp, mpfr, mpc) ──> gcc/9.5.0 ──> openmpi/5.0.8-gcc9
```

O CLI resolve essa árvore recursivamente e reutiliza dependências já instaladas. Não há solver separado: o mecanismo é apenas a recursão sobre `depends=` do manifesto.

## Shell das receitas

Fish é o formato principal. Um pacote pode fornecer `build.sh` e `test.sh` equivalentes:

```bash
HPC_RECIPE_SHELL=bash hpc install openmpi/5.0.8-gcc9
```

O manifesto `package.conf`, patches e modulefile são compartilhados pelas duas implementações.

## Estado atual

Receitas completas ou funcionais:

- GMP 6.1.0;
- MPFR 4.1.0 (`gmp/6.1.0`);
- MPC 1.2.1 (`gmp/6.1.0`, `mpfr/4.1.0`);
- GCC 9.5.0 (`gmp/6.1.0`, `mpfr/4.1.0`, `mpc/1.2.1`);
- OpenMPI 5.0.8 + GCC 9.5.0;
- OpenBLAS 0.3.30 + GCC 9.5.0 (`DYNAMIC_ARCH=1`, BLAS/LAPACK testados).

GCC é configurado com os prefixos fornecidos pelos modulefiles das três dependências e com ISL desabilitado nesta etapa. Isso evita dependências silenciosas em pacotes `*-devel` da distribuição e mantém download, versão e checksum sob controle do TinyHPC.

Stack alvo validada manualmente:

- GCC 9.5.0;
- OpenMPI 5.0.8;
- OpenBLAS 0.3.30;
- FFTW 3.3.10;
- ScaLAPACK 2.2.0;
- OpenMX 4.0 + patch 4.0.1.

O objetivo incremental é chegar a:

```fish
hpc install openmx/4.0
```

com resolução automática de toda a stack.

## Filosofia

O Git guarda apenas o que torna a instalação reproduzível: receitas, versões, URLs, checksums, patches, modulefiles e testes. Fontes extraídas e builds podem ser descartados; o cache de downloads pode ser preservado.
