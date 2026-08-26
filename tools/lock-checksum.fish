#!/usr/bin/env fish
set repo (realpath (dirname (status filename))/..)
source $repo/lib/common.fish
hpc_load_defaults $repo

set spec $argv[1]
test -n "$spec"; or begin
    echo "uso: tools/lock-checksum.fish <pacote/versao> [--write]" >&2
    exit 1
end
set write 0
if contains -- --write $argv
    set write 1
end

set d $repo/packages/$spec
test -f $d/package.conf; or hpc_die "pacote desconhecido: $spec"
hpc_read_manifest $d/package.conf
mkdir -p $HPC_CACHE

function checksum_artifact
    set label $argv[1]
    set url $argv[2]
    set archive $argv[3]
    set key $argv[4]
    set manifest $argv[5]
    set do_write $argv[6]

    test -n "$url"; or return 0
    test -n "$archive"; or hpc_die "$label: archive ausente no manifesto"

    set f $HPC_CACHE/$archive
    if not test -f $f
        hpc_note "baixando $archive"
        curl -fL --retry 3 -o $f $url; or hpc_die "download falhou: $url"
    else
        hpc_note "usando cache $archive"
    end

    set sum (sha256sum $f | string split ' ' | head -n1)
    echo "$key=$sum"

    if test "$do_write" = 1
        if grep -q "^$key=" $manifest
            sed -i -E "s|^$key=.*|$key=$sum|" $manifest
        else
            echo "$key=$sum" >> $manifest
        end
    end
end

set manifest $d/package.conf
checksum_artifact source $PKG_source $PKG_archive sha256 $manifest $write

if set -q PKG_patch_source; and test -n "$PKG_patch_source"
    checksum_artifact patch $PKG_patch_source $PKG_patch_archive patch_sha256 $manifest $write
end

if test $write = 1
    hpc_note "checksums gravados em $manifest"
    echo "Revise package.conf e rode ./bootstrap.fish antes de instalar."
else
    echo "Use --write para atualizar package.conf automaticamente."
end
