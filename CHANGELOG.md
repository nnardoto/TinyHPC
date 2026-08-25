# Changelog

## v0.6.0

- add complete FFTW 3.3.10 GCC 9 recipe
- enable shared FFTW libraries and pthread threading
- add functional threaded forward/backward DFT tests for Fish and Bash
- lock FFTW 3.3.10 SHA-256

## v0.5.0 — OpenBLAS 0.3.30

- adiciona receita completa `openblas/0.3.30-gcc9`;
- build portátil com `DYNAMIC_ARCH=1` e threading pthread;
- usa `NO_AFFINITY=1` para não impor afinidade sobre SLURM/usuário;
- embute rpath para os runtimes do GCC 9 sem adicionar o runtime do GCC a `LD_LIBRARY_PATH`;
- testes numéricos de BLAS (`DGEMM`) e LAPACK (`DGESV`);
- receitas equivalentes em Fish e Bash.

## v0.4.3 — GCC module sem contaminação do shell

- remove `gcc/9.5.0/lib64` e `gcc/9.5.0/lib` de `LD_LIBRARY_PATH` no modulefile do GCC;
- evita que carregar GCC 9.5.0 force o Fish e outras ferramentas do sistema a usar uma `libstdc++.so.6` antiga;
- mantém `PATH`, `LIBRARY_PATH`, `CPATH`, `CC`, `CXX`, `FC` e `GCC_ROOT` para o ambiente de compilação;
- modulefiles instalados continuam sendo sincronizados automaticamente ao reutilizar um pacote já instalado.

## v0.4.2 — sincronização de modulefiles

- sincroniza modulefiles instalados com a receita atual antes de reutilizar um pacote;
- evita estado obsoleto após mudanças de receita ou versão.

## v0.4.1 — MPC 1.2.1 e modulefiles robustos

- atualiza MPC de 1.0.3 para 1.2.1, compatível com MPFR 4.1.0;
- atualiza a dependência do GCC 9.5.0 para `mpc/1.2.1`;
- trava o SHA-256 oficial/reproduzível do tarball `mpc-1.2.1.tar.gz`;
- modulefiles de GMP, MPFR, MPC, GCC e OpenMPI passam a derivar o caminho da própria versão via `myModuleVersion()`;
- elimina o bug em que renomear uma receita podia manter um prefixo antigo hardcoded no modulefile;
- GCC valida `GMP_ROOT`, `MPFR_ROOT` e `MPC_ROOT` antes do configure e falha com diagnóstico direto se algum prefixo estiver incorreto.

## v0.4.0 — árvore explícita de bootstrap do GCC

- adiciona receitas completas Fish + Bash para GMP 6.1.0, MPFR 4.1.0 e MPC 1.0.3;
- cada receita possui URL, SHA-256 travado, teste funcional e modulefile;
- MPFR declara `gmp/6.1.0` como dependência;
- MPC declara `gmp/6.1.0,mpfr/4.1.0`;
- GCC 9.5.0 passa a declarar as três bibliotecas como dependências normais;
- remove `contrib/download_prerequisites` da receita do GCC;
- GCC usa `GMP_ROOT`, `MPFR_ROOT` e `MPC_ROOT` exportados pelos modulefiles;
- GCC é configurado com `--without-isl` para manter o bootstrap mínimo;
- o resolvedor existente permanece simples: recursão sobre `depends=` e reutilização do que já está instalado.


## v0.3.1 — bootstrap completo do GCC

- a receita GCC 9.5.0 passa a executar `contrib/download_prerequisites` após extrair a fonte;
- GMP, MPFR, MPC e ISL usados pelo GCC são obtidos pelo fluxo oficial da própria release;
- a correção foi aplicada às receitas Fish e Bash;
- elimina a dependência implícita de pacotes `*-devel` da distribuição para construir GCC.

## v0.3.0 — baseline do primeiro commit

- projeto consolidado como **TinyHPC**;
- identidade: `TinyHPC — minimal tooling for reproducible HPC.`;
- separação entre gerenciador (`/opt/tinyhpc`) e stack gerenciada (`/opt/hpc`);
- CLI instalado em `/usr/local/bin/hpc`;
- novas variáveis centrais `TINYHPC_HOME` e `TINYHPC_ROOT`;
- modulefiles passam a derivar o prefixo de `TINYHPC_ROOT`;
- bootstrap Fish e Bash instala/detecta Lmod e configura o ambiente;
- bootstrap Bash instala Fish quando necessário;
- `TINYHPC_ROOT` é a fonte de verdade para o prefixo; `HPC_ROOT` permanece apenas como alias interno de compatibilidade;
- receita GCC 9.5.0 funcional;
- receita OpenMPI 5.0.8 + GCC 9.5.0 com dependência automática, checksum, teste, modulefile e variante Bash.
