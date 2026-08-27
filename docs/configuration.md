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
```

## Campos

- `paths.home`: local de instalação do gerenciador;
- `paths.root`: raiz da stack gerenciada;
- `build.jobs`: paralelismo padrão dos builds;
- `build.profile`: perfil de otimização disponível para receitas e futuras variantes.

Os diretórios de cache, fontes, builds, software, modulefiles e logs são derivados de `paths.root`.

Use:

```bash
hpc config
```

para exibir a origem da configuração e os valores efetivos. Um override temporário não exige editar o TOML:

```bash
HPC_JOBS=16 hpc install gcc/9.5.0/openmpi/5.0.8
```

Após editar o TOML em um shell que já carregou o TinyHPC, recarregue o ambiente:

```bash
unset TINYHPC_ROOT HPC_JOBS HPC_PROFILE
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
