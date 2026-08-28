#!/usr/bin/env fish
set repo (realpath (dirname (status filename))/..)
source $repo/lib/common.fish
hpc_load_defaults $repo

set spec $argv[1]
set d $repo/packages/$spec
hpc_read_manifest $d/package.conf
mkdir -p $HPC_CACHE
set f $HPC_CACHE/$PKG_archive
if not test -f $f
    curl -fL --retry 3 -o $f $PKG_source; or exit 1
end
set sum (sha256sum $f | string split ' ' | head -n1)
echo "sha256=$sum"
echo "Substitua sha256=UNSET em $d/package.conf"
