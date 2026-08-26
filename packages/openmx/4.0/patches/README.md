# OpenMX 4.0.1 patch

The official patch is distributed as `patch4.0.1.tar.gz` by openmx-square.org.
It is not copied into the TinyHPC repository. Its version, URL and SHA-256 are
recorded in `package.conf`, and the archive is kept in the TinyHPC cache.

Upstream release note (08/May/2026) says the archive contains:

- `Band_DFT_Dosout.c`
- `Mulliken_Charge.c`
- `GaAs.dat`

The build recipe verifies all three files before compiling.
