# Configuração

O TinyHPC lê a configuração nesta ordem, da menor para a maior precedência:

1. `config/defaults.toml`, distribuído com o gerenciador;
2. `${XDG_CONFIG_HOME:-$HOME/.config}/tinyhpc/config.toml`;
3. o arquivo indicado por `TINYHPC_CONFIG`, quando definido;
4. variáveis de ambiente.

O bootstrap cria a configuração do usuário sem sobrescrever um arquivo existente.

```toml
schema = 1

[paths]
home = "/opt/tinyhpc"
root = "/opt/hpc"

[build]
jobs = 8
profile = "native"

[mirrors]
gnu = [
  "https://ftp.gnu.org/gnu/",
  "https://ftp.unicamp.br/pub/gnu/",
  "https://gnu.c3sl.ufpr.br/ftp/",
]
```

## Campos

- `paths.home`: local de instalação do gerenciador;
- `paths.root`: raiz da stack gerenciada;
- `build.jobs`: paralelismo padrão dos builds;
- `build.profile`: perfil de otimização usado pelas receitas científicas.
- `mirrors.<grupo>`: fontes-base tentadas em ordem para receitas que usam o grupo.

Cada grupo de espelhos é uma lista não vazia de URLs. A configuração do usuário
substitui a lista padrão do grupo inteiro, permitindo alterar a prioridade em um
único lugar sem editar receitas. Por exemplo:

```toml
[mirrors]
gnu = [
  "https://ftp.unicamp.br/pub/gnu/",
  "https://gnu.c3sl.ufpr.br/ftp/",
]
```

O TinyHPC concatena cada URL-base ao `source.path` da receita e tenta os
resultados na ordem declarada. Fontes que não pertencem a um repositório
espelhado continuam usando `source.url` diretamente.

O perfil gera `HPC_OPT_FLAGS` automaticamente:

- `native`: `-O3 -march=native -mtune=native`;
- `generic`: `-O3`.

No OpenBLAS, `native` compila somente o kernel detectado na máquina, enquanto
`generic` gera uma biblioteca com seleção dinâmica de arquitetura em runtime.

`native` produz binários específicos para a CPU que executa o build. Não copie
essa instalação para outra arquitetura; faça um build independente em cada
máquina. As receitas não usam `-ffast-math`, preservando a semântica numérica.

Os diretórios de cache, fontes, builds, software, modulefiles e logs são derivados de `paths.root`.
Cada pacote instala seus arquivos em `software/<spec>/.prefix`; assim, rebuilds
de compiladores e MPI não removem os prefixes dos pacotes descendentes.

### Migração do layout anterior

Instalações criadas antes do layout `.prefix` não são apagadas nem migradas
automaticamente. Na primeira instalação com a versão nova, os pacotes serão
recompilados no novo prefixo e os arquivos antigos continuarão ocupando disco.
Para stacks grandes, prefira configurar uma nova `paths.root`; depois de testar
a stack nova, arquive ou remova manualmente a raiz antiga. Não compartilhe uma
stack `native` entre o Xeon e o Ryzen.

Use:

```bash
hpc config
```

para exibir a origem da configuração e os valores efetivos. Um override temporário não exige editar o TOML:

```bash
HPC_JOBS=16 hpc install gcc/9.5.0/openmpi/5.0.8
```

## Contexto de compilador

O contexto de compilador é uma preferência da CLI, separada do `config.toml`.
Ele é armazenado como uma única spec canônica em
`${XDG_CONFIG_HOME:-$HOME/.config}/tinyhpc/compiler` e não participa de
fingerprints, instalações ou modulefiles.

```bash
hpc compilers                 # lista os compiladores e marca o selecionado
hpc compiler                  # mostra o contexto atual
hpc compiler gcc/16.2.0       # resolve e seleciona um compilador
hpc compiler --clear          # remove o contexto
hpc resolve quantum-espresso/7.6
```

Com contexto selecionado, queries não canônicas são procuradas somente dentro
da árvore daquele compilador, sem fallback global. Uma spec canônica completa
e existente é sempre aceita diretamente. A regra de resolução é estrita:

```text
0 correspondências  -> não encontrado
1 correspondência   -> spec canônica
mais de 1            -> ambígua
```

**Short specs are accepted only when they resolve to exactly one canonical spec.**

**Compiler context narrows resolution; it never resolves ambiguity.**

Não há seleção automática por versão, provider, MPI ou ordem dos resultados.
O matching usa componentes exatos do sufixo da spec; `quantum` não corresponde
silenciosamente a `quantum-espresso`.

Após editar o TOML em um shell que já carregou o TinyHPC, recarregue o ambiente:

```bash
unset TINYHPC_ROOT HPC_JOBS HPC_PROFILE HPC_OPT_FLAGS HPC_OPENBLAS_DYNAMIC_ARCH HPC_MIRRORS
eval "$(hpc env)"
module use "$HPC_MODULEFILES"
```

`hpc env` pode emitir atribuições escapadas para cada interface:

```bash
hpc env --shell bash
hpc env --shell zsh
hpc env --shell fish
```

Os adaptadores em `shell/` consomem essa saída; nenhuma lógica de build é duplicada entre os shells.

## Execução híbrida

As stacks científicas usam MPI + OpenMP e OpenBLAS sequencial, evitando pools
de threads aninhados. Ajuste ranks e threads conforme o cálculo; por exemplo:

```bash
export OMP_NUM_THREADS=2
export OMP_PLACES=cores
export OMP_PROC_BIND=close
export OPENBLAS_NUM_THREADS=1
mpirun -np 7 pw.x -in scf.in
```

No Xeon E5-2680 v4, comece comparando `14 x 1`, `7 x 2` e `4 x 3`/`4 x 4`.
No Ryzen 9 7950X, compare `16 x 1`, `8 x 2` e `4 x 4`; use inicialmente os
núcleos físicos, não os threads SMT. O melhor arranjo depende do tamanho das
FFT, da memória por rank e da paralelização em k-points/bandas.
