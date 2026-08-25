#!/usr/bin/env fish
source $TINYHPC_REPO/lib/common.fish
hpc_load_defaults $TINYHPC_REPO
hpc_read_manifest $HPC_PACKAGE_DIR/package.conf

set archive $HPC_CACHE/$PKG_archive
set src $HPC_SRC/$PKG_source_dir
set build $HPC_BUILD/$PKG_build_dir

hpc_fetch $PKG_source $archive $PKG_sha256
hpc_extract $archive $HPC_SRC $PKG_source_dir
hpc_apply_patches $src $HPC_PACKAGE_DIR/patches

command -q $CC; or hpc_die "CC inválido: $CC"
command -q $FC; or hpc_die "FC inválido: $FC"

rm -rf $build
mkdir -p $build
cd $build

$src/configure \
    --prefix=$HPC_PREFIX \
    --enable-shared \
    --disable-static \
    --enable-threads \
    CC=$CC \
    F77=$FC \
    FC=$FC
or exit 1

make -j$HPC_JOBS
or exit 1

make install
or exit 1
