#!/usr/bin/env fish
source $TINYHPC_REPO/lib/common.fish
hpc_load_defaults $TINYHPC_REPO
hpc_read_manifest $HPC_PACKAGE_DIR/package.conf

set archive $HPC_CACHE/$PKG_archive
set src $HPC_SRC/$PKG_source_dir

hpc_fetch $PKG_source $archive $PKG_sha256
hpc_extract $archive $HPC_SRC $PKG_source_dir
hpc_apply_patches $src $HPC_PACKAGE_DIR/patches

# OpenBLAS' gmake build is intentionally in-tree. hpc clean removes this
# extracted source tree afterwards, while the downloaded tarball stays cached.
cd $src

test -x $CC; or hpc_die "CC inválido: $CC"
test -x $FC; or hpc_die "FC inválido: $FC"
test -d $GCC_ROOT/lib64; or hpc_die "GCC_ROOT inválido: $GCC_ROOT/lib64 não existe"

set rpath_flags "-Wl,-rpath,$GCC_ROOT/lib64 -Wl,-rpath,$GCC_ROOT/lib"

make -j$HPC_JOBS \
    CC=$CC \
    FC=$FC \
    HOSTCC=$CC \
    DYNAMIC_ARCH=1 \
    USE_THREAD=1 \
    USE_OPENMP=0 \
    NO_AFFINITY=1 \
    LDFLAGS="$rpath_flags"
or exit 1

make \
    PREFIX=$HPC_PREFIX \
    CC=$CC \
    FC=$FC \
    HOSTCC=$CC \
    DYNAMIC_ARCH=1 \
    USE_THREAD=1 \
    USE_OPENMP=0 \
    NO_AFFINITY=1 \
    LDFLAGS="$rpath_flags" \
    install
or exit 1
