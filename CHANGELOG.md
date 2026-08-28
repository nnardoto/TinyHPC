# Changelog

## v0.1.0 — engine TOML e CLI hierárquico

Versão inicial do TinyHPC.

- CLI `hpc` em Bash com motor em Python (parser TOML vendorizado para Python 3.9/3.10);
- receitas `package.toml` hierárquicas com validação de schema, checksum e geração automática de modulefiles;
- builders declarativos `autotools`, `cmake`, `make` e `script`;
- resolução de dependências por herança de caminho e ordenação topológica;
- comandos `list`, `compilers`, `compiler`, `resolve`, `info`, `config`, `env`, `plan`, `validate`, `new`, `lock`, `install`, `clean`, `remove` e `doctor`;
- resolução determinística de specs curtas na fronteira de `install`, com contexto opcional e persistente de compilador;
- bootstrap idempotente que detecta ou instala Lmod e cria interfaces Bash, Zsh e Fish;
- configuração TOML em camadas (`config/defaults.toml`, configuração do usuário e variáveis de ambiente);
- receitas atuais: GMP 6.1.0/6.3.0, MPFR 4.1.0/4.2.2, MPC 1.2.1/1.3.1, ISL 0.24, GCC 9.5.0/16.2.0, OpenBLAS 0.3.30, FFTW 3.3.10, Open MPI 5.0.8, ScaLAPACK 2.2.0 e Quantum ESPRESSO 7.6;
- Graphite habilitado nas toolchains GCC 9.5.0 e 16.2.0 por meio do ISL 0.24.
- stacks completas de Open MPI, OpenBLAS, FFTW, ScaLAPACK, Quantum ESPRESSO e OpenMX disponíveis para GCC 9.5.0 e 16.2.0;
- perfil de otimização aplicado às receitas com `HPC_OPT_FLAGS`, SIMD nativo no FFTW e modelo híbrido MPI + OpenMP com OpenBLAS sequencial;
- prefixes físicos isolados por pacote, fingerprints transitivos e upgrades com rollback para reconstrução segura após mudanças de receita ou perfil.
