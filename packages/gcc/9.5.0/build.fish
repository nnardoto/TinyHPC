#!/usr/bin/env fish
source $TINYHPC_REPO/lib/common.fish
hpc_load_defaults $TINYHPC_REPO
hpc_read_manifest $HPC_PACKAGE_DIR/package.conf

for dep in GMP MPFR MPC
    set root_var {$dep}_ROOT
    set root $$root_var
    test -n "$root"; or hpc_die "$root_var não definido; verifique o modulefile da dependência"
    test -d "$root/include"; or hpc_die "$root_var inválido: $root/include não existe"
    test -d "$root/lib"; or hpc_die "$root_var inválido: $root/lib não existe"
end

set archive $HPC_CACHE/$PKG_archive
set src $HPC_SRC/$PKG_source_dir
set build $HPC_BUILD/$PKG_build_dir

hpc_fetch $PKG_source $archive $PKG_sha256
hpc_extract $archive $HPC_SRC $PKG_source_dir

rm -rf $build
mkdir -p $build
cd $build

$src/configure \
  --prefix=$HPC_PREFIX \
  --enable-languages=c,c++,fortran \
  --disable-multilib \
  --disable-bootstrap \
  --disable-libsanitizer \
  --with-gmp=$GMP_ROOT \
  --with-mpfr=$MPFR_ROOT \
  --with-mpc=$MPC_ROOT \
  --without-isl
or exit 1

make -j$HPC_JOBS
or exit 1

make install
or exit 1
