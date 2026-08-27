# Receitas hierárquicas

Cada receita reside em `packages/<nome>/<versão>/package.toml`. Pares adicionais de nome e versão representam a toolchain:

```text
gcc/9.5.0/openmpi/5.0.8/quantum-espresso/7.6
```

O pai imediato é uma dependência implícita. Dependências declaradas com nomes curtos são procuradas primeiro no contexto do pai, depois no contexto do compilador e finalmente na raiz.

## Schema mínimo

```toml
schema = 1

[package]
name = "zlib"
version = "1.3.1"
description = "zlib 1.3.1"
dependencies = []

[source]
url = "https://example.org/zlib-1.3.1.tar.gz"
sha256 = "UNSET"
directory = "zlib-1.3.1"

[build]
system = "autotools"
arguments = []

[module]
root_environment = ["ZLIB_ROOT"]

[module.paths]
LD_LIBRARY_PATH = ["lib"]
CPATH = ["include"]
```

Use `hpc lock <spec>` para baixar a fonte e preencher `source.sha256`. A instalação é recusada enquanto o checksum não estiver travado.

## Build

`build.system` aceita:

- `autotools`: executa `configure`, `make` e `make install` fora da árvore de fontes;
- `cmake`: executa configure, build e install fora da árvore de fontes;
- `make`: usa a árvore de fontes por padrão;
- `script`: executa o arquivo indicado por `build.script`.

Valores em `arguments`, `install_arguments` e `build.environment` aceitam `{prefix}`, `{source}`, `{build}`, `{jobs}` e variáveis como `${MPI_ROOT}`. Comandos externos adicionais podem ser verificados com `build.requires`.

## Modulefiles

`module.root_environment` define variáveis que apontam para o prefixo. `module.paths` acrescenta caminhos relativos, e `module.environment` define valores adicionais:

```toml
[module]
family = "compiler"
root_environment = ["GCC_ROOT"]

[module.paths]
PATH = ["bin"]
LIBRARY_PATH = ["lib64", "lib"]

[module.environment]
CC = "{root}/bin/gcc"
FC = "{root}/bin/gfortran"
```

Dependências e `MODULEPATH` dos filhos são incluídos automaticamente no Lua gerado.

## Testes

```toml
[[tests]]
type = "executable"
path = "bin/programa"

[[tests]]
type = "file"
path = "lib/libprograma.so"

[[tests]]
type = "command"
command = ["{prefix}/bin/programa", "--version"]
```

Testes complexos podem ser escritos em Bash:

```toml
[[tests]]
type = "script"
path = "test.sh"
```

## Fluxo para um pacote novo

```bash
hpc new gcc/9.5.0/zlib/1.3.1 --build-system autotools
# editar source.url e as opções específicas
hpc lock gcc/9.5.0/zlib/1.3.1
hpc validate gcc/9.5.0/zlib/1.3.1
hpc plan gcc/9.5.0/zlib/1.3.1
hpc install gcc/9.5.0/zlib/1.3.1
```
