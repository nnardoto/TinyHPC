# OpenMX 4.0 + official patch 4.0.1

TinyHPC recipe for the validated GNU stack:

- GCC 9.5.0
- OpenMPI 5.0.8
- OpenBLAS 0.3.30
- FFTW 3.3.10
- ScaLAPACK 2.2.0
- OpenMX 4.0
- official OpenMX patch 4.0.1 (08/May/2026)

The upstream patch archive is applied exactly in the layout described by the
OpenMX release note: its C sources overwrite files in `openmx4.0/source`, and
its corrected `GaAs.dat` replaces `openmx4.0/work/GaAs.dat`.

The installed prefix is `software/openmx/4.0.1-gcc9`, while the recipe spec is
kept as `openmx/4.0`; this makes `hpc install openmx/4.0` mean “install the
supported OpenMX 4.0, including the current official patch level”.

## First checksum lock

OpenMX's download page does not publish SHA-256 values. Before the first build,
lock the two official archives locally and commit the resulting manifest:

```fish
./tools/lock-checksum.fish openmx/4.0 --write
```

Then reinstall TinyHPC with `./bootstrap.fish` and run:

```fish
hpc install openmx/4.0
```

The recipe installs the `openmx` executable, `DFT_DATA19`, and the upstream
`work` examples. The smoke test runs the bundled H2O example with one MPI rank
and one OpenMP thread.
