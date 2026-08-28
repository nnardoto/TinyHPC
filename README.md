# TinyHPC

TinyHPC é um gerenciador pessoal e reproduzível de stacks HPC: um CLI em Bash com receitas TOML, Lmod e Python que instala e mantém software científico de forma determinística.

## Requisitos

- Linux;
- Bash (motor, CLI e bootstrap);
- Python 3.9 ou mais recente (o parser TOML está incluído no repositório);
- ferramentas de build por receita (`curl`, `tar`, `make`, `cmake`, `patch`, `sha256sum`, etc.);
- Lmod: detectado ou instalado automaticamente pelo bootstrap (`pacman`, `apt-get`, `dnf` ou `zypper`).

## Quick start

```bash
git clone https://github.com/nnardoto/TinyHPC.git
cd TinyHPC
./bootstrap.sh
source ~/.config/tinyhpc/bashrc
hpc doctor
```

O bootstrap é idempotente: instala o gerenciador em `/opt/tinyhpc`, cria o CLI `/usr/local/bin/hpc`, monta a árvore `/opt/hpc`, configura o Lmod e gera as interfaces de shell. `hpc doctor` verifica o ambiente e as ferramentas necessárias.

## Uso

```bash
hpc list
hpc info gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6
hpc plan gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6
hpc install gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6
module load gcc/9.5.0
module load openmpi/5.0.8
module load quantum-espresso/7.6
command -v pw.x
```

`hpc list` mostra as receitas disponíveis, `hpc info` exibe metadados e dependências, `hpc plan` imprime a ordem de build (GMP, MPFR, MPC, GCC, Open MPI, OpenBLAS, FFTW, ScaLAPACK e Quantum ESPRESSO) e `hpc install` resolve as dependências, reutilizando o que já está instalado.

## Shells

Bash, Zsh e Fish têm interfaces sourceáveis criadas pelo bootstrap:

```bash
source ~/.config/tinyhpc/bashrc    # Bash
source ~/.config/tinyhpc/zshrc     # Zsh
source ~/.config/tinyhpc/fish.fish # Fish
```

## Arquitetura, configuração e receitas

O projeto separa o gerenciador (`/opt/tinyhpc`) da stack gerenciada (`/opt/hpc`). Receitas são TOML hierárquicos em `packages/`; o caminho define identidade e herança (por exemplo, `gcc/9.5.0/openmpi/5.0.8`). Veja [docs/configuration.md](docs/configuration.md) e [docs/recipes.md](docs/recipes.md).

## Receitas disponíveis

- GMP 6.1.0;
- MPFR 4.1.0;
- MPC 1.2.1;
- GCC 9.5.0;
- OpenBLAS 0.3.30 (GCC 9.5.0);
- FFTW 3.3.10 (GCC 9.5.0);
- Open MPI 5.0.8 (GCC 9.5.0);
- ScaLAPACK 2.2.0 (Open MPI 5.0.8 + OpenBLAS 0.3.30);
- Quantum ESPRESSO 7.6 (stack completa).

Este é um projeto inicial (v0.1.0) em desenvolvimento ativo.
