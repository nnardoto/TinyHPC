# Changelog

## v0.1.0 — engine TOML e CLI hierárquico

Versão inicial do TinyHPC.

- CLI `hpc` em Bash com motor em Python (parser TOML vendorizado para Python 3.9/3.10);
- receitas `package.toml` hierárquicas com validação de schema, checksum e geração automática de modulefiles;
- builders declarativos `autotools`, `cmake`, `make` e `script`;
- resolução de dependências por herança de caminho e ordenação topológica;
- comandos `list`, `info`, `config`, `env`, `plan`, `validate`, `new`, `lock`, `install`, `clean`, `remove` e `doctor`;
- bootstrap idempotente que detecta ou instala Lmod e cria interfaces Bash, Zsh e Fish;
- configuração TOML em camadas (`config/defaults.toml`, configuração do usuário e variáveis de ambiente);
- receitas atuais: GMP 6.1.0, MPFR 4.1.0, MPC 1.2.1, GCC 9.5.0, OpenBLAS 0.3.30, FFTW 3.3.10, Open MPI 5.0.8, ScaLAPACK 2.2.0 e Quantum ESPRESSO 7.6.
