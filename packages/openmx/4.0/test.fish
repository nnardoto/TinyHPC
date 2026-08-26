#!/usr/bin/env fish
set exe $HPC_PREFIX/bin/openmx
set data $HPC_PREFIX/DFT_DATA19
set example $HPC_PREFIX/work/input_example/H2O.dat

test -x $exe; or exit 1
test -d $data; or exit 1
test -f $example; or exit 1

# Nenhuma dependência dinâmica pode ficar sem resolução.
if ldd $exe | grep -q 'not found'
    ldd $exe
    exit 1
end

# Smoke test pequeno e reprodutível usando o exemplo H2O distribuído pelo OpenMX.
set t (mktemp -d)
function cleanup --on-event fish_exit
    rm -rf $t
end
cp $example $t/H2O.dat
sed -i -E "s|^[[:space:]]*DATA\.PATH[[:space:]]+.*|DATA.PATH                        $data|" $t/H2O.dat

set -lx OPENBLAS_NUM_THREADS 1
set -lx OMP_NUM_THREADS 1
cd $t
$MPI_ROOT/bin/mpirun -n 1 $exe H2O.dat -nt 1 > H2O.std 2>&1
or begin
    cat H2O.std
    exit 1
end
