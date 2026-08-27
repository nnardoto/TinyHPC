# TinyHPC

**TinyHPC — minimal tooling for reproducible HPC.**

TinyHPC é um gerenciador pessoal, pequeno e reproduzível para stacks HPC. O CLI é escrito em Bash, usa Lmod para ambientes e mantém receitas hierárquicas em TOML, com checksums, patches, testes e modulefiles gerados automaticamente. Python 3.9 ou mais recente é necessário; o parser TOML acompanha o projeto.

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

As raízes e opções de build são configuradas em `~/.config/tinyhpc/config.toml`:

```toml
schema = 1

[paths]
home = "/opt/tinyhpc"
root = "/opt/hpc"

[build]
jobs = 4
profile = "native"
```

`config/defaults.toml` fornece os valores padrão. A configuração do usuário os sobrescreve, e variáveis de ambiente como `TINYHPC_ROOT` e `HPC_JOBS` têm a maior precedência. Use `hpc config` para inspecionar os valores efetivos; veja também [docs/configuration.md](docs/configuration.md). As receitas não devem depender diretamente desses caminhos padrão.

## Bootstrap

```bash
./bootstrap.sh
source ~/.config/tinyhpc/bashrc
hpc doctor
```

O bootstrap é idempotente e:

- detecta ou instala Lmod;
- instala uma cópia do TinyHPC em `/opt/tinyhpc`;
- cria `/usr/local/bin/hpc` apontando para `/opt/tinyhpc/bin/hpc`;
- cria a árvore gerenciada em `/opt/hpc`;
- adiciona `/opt/hpc/modulefiles` ao Lmod;
- cria `~/.config/tinyhpc/config.toml` e interfaces para Bash, Zsh e Fish.

## Interfaces de shell

O motor, o CLI e scripts especiais usam Bash. As interfaces de usuário apenas carregam a configuração, inicializam Lmod e ajustam `MODULEPATH`; elas não implementam builds ou resolução de dependências.

O bootstrap cria três arquivos sourceáveis:

```bash
# Bash
source ~/.config/tinyhpc/bashrc

# Zsh
source ~/.config/tinyhpc/zshrc
```

```fish
# Fish
source ~/.config/tinyhpc/fish.fish
```

As interfaces versionadas ficam em `shell/init.bash`, `shell/init.zsh` e `shell/init.fish`. O mesmo ambiente também pode ser emitido diretamente:

```bash
hpc env --shell bash
hpc env --shell zsh
hpc env --shell fish
```

Gerenciadores de pacotes detectados atualmente: `pacman`, `apt-get`, `dnf` e `zypper`.

Para usar outros prefixos desde o primeiro bootstrap:

```bash
TINYHPC_HOME="$HOME/.local/opt/tinyhpc" \
TINYHPC_ROOT="$HOME/.local/hpc" \
TINYHPC_BIN="$HOME/.local/bin/hpc" \
TINYHPC_SUDO= \
./bootstrap.sh
```

`TINYHPC_BIN` mantém `/usr/local/bin/hpc` como padrão. Defina `TINYHPC_SUDO=` quando todos os destinos forem graváveis pelo usuário; a instalação padrão continua usando `sudo`.

## Comandos

```text
hpc list
hpc info <spec>
hpc config
hpc plan <spec>
hpc validate [spec]
hpc new <spec> [--build-system autotools|cmake|make|script]
hpc lock <spec>
hpc install <spec>
hpc clean <spec>
hpc remove <spec>
hpc doctor
```

Exemplo:

```bash
hpc info gcc/9.5.0/openmpi/5.0.8
hpc install gcc/9.5.0/openmpi/5.0.8
module load gcc/9.5.0
module load openmpi/5.0.8
mpirun --version
```

`gcc/9.5.0/openmpi/5.0.8` herda `gcc/9.5.0` do caminho. O GCC, por sua vez, declara seus pré-requisitos matemáticos como receitas normais:

```text
gmp/6.1.0
   ├──> mpfr/4.1.0
   └────────────┐
                ├──> mpc/1.2.1
mpfr/4.1.0 ─────┘

(gmp, mpfr, mpc) ──> gcc/9.5.0 ──> openmpi/5.0.8
```

O CLI resolve essa árvore recursivamente e reutiliza dependências já instaladas. Não há solver separado: o mecanismo é uma ordenação topológica das dependências herdadas e declaradas no TOML.

## Receitas hierárquicas

Programas compilados por uma toolchain residem sob o compilador; programas ligados a MPI residem sob a implementação MPI:

```text
packages/
├── gmp/6.1.0/package.toml
├── mpfr/4.1.0/package.toml
├── mpc/1.2.1/package.toml
└── gcc/9.5.0/
    ├── package.toml
    ├── fftw/3.3.10/package.toml
    ├── openblas/0.3.30/package.toml
    └── openmpi/5.0.8/
        ├── package.toml
        ├── scalapack/2.2.0/package.toml
        └── quantum-espresso/7.6/package.toml
```

O caminho é a identidade canônica. A receita herda o pacote-pai automaticamente e declara apenas dependências laterais. Por exemplo, ScaLAPACK herda Open MPI e localiza `openblas/0.3.30` dentro do contexto GCC mais próximo.

Builders disponíveis: `autotools`, `cmake`, `make` e `script`. O último é uma escape hatch para processos especiais. Consulte [docs/recipes.md](docs/recipes.md) para o schema completo.

O modulefile também é derivado do TOML. Ao carregar um compilador ou MPI, seus filhos são adicionados ao `MODULEPATH`:

```bash
module load gcc/9.5.0
module load openmpi/5.0.8
module load quantum-espresso/7.6
```

## Quantum ESPRESSO como objetivo

```bash
hpc validate gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6
hpc plan gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6
hpc install gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6
```

O plano inclui GMP, MPFR, MPC, GCC, Open MPI, OpenBLAS, FFTW e ScaLAPACK. A receita usa o CMake oficial do Quantum ESPRESSO 7.6 com MPI, OpenMP e as bibliotecas matemáticas da mesma hierarquia. Dependências internas do código são obtidas pelo mecanismo upstream a partir dos commits registrados em `external/submodule_commit_hash_records`.

## Estado atual

Receitas TOML disponíveis:

- GMP 6.1.0;
- MPFR 4.1.0 (`gmp/6.1.0`);
- MPC 1.2.1 (`gmp/6.1.0`, `mpfr/4.1.0`);
- GCC 9.5.0 (`gmp/6.1.0`, `mpfr/4.1.0`, `mpc/1.2.1`);
- OpenMPI 5.0.8 + GCC 9.5.0;
- OpenBLAS 0.3.30 + GCC 9.5.0;
- FFTW 3.3.10 + GCC 9.5.0;
- ScaLAPACK 2.2.0 + Open MPI 5.0.8;
- Quantum ESPRESSO 7.6 + a stack acima.

GCC é configurado com os prefixos fornecidos pelos modulefiles das três dependências e com ISL desabilitado nesta etapa. Isso evita dependências silenciosas em pacotes `*-devel` da distribuição e mantém download, versão e checksum sob controle do TinyHPC.

O objetivo de integração declarativa é:

```bash
hpc install gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6
```

com resolução automática de toda a stack. `hpc plan` e os testes automatizados validam a resolução; a compilação integral continua sendo a validação de integração em uma máquina Linux alvo.

## Filosofia

O Git guarda apenas o que torna a instalação reproduzível: receitas, versões, URLs, checksums, patches, modulefiles e testes. Fontes extraídas e builds podem ser descartados; o cache de downloads pode ser preservado.

## Receitas legadas

Os arquivos `package.conf`, `build.sh` e modulefiles escritos manualmente permanecem no repositório durante a migração, inclusive a receita OpenMX 4.0. O novo CLI descobre apenas `package.toml`; receitas legadas devem ser migradas para aparecer em `hpc list`.
