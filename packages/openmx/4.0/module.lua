local version = myModuleVersion()
help([[OpenMX 4.0 with the official 4.0.1 patch, built by TinyHPC]])
whatis("Name: OpenMX")
whatis("Base version: 4.0")
whatis("Patch level: 4.0.1")
whatis("Compiler: GCC 9.5.0")
whatis("MPI: OpenMPI 5.0.8")
whatis("BLAS/LAPACK: OpenBLAS 0.3.30")
whatis("FFTW: 3.3.10")
whatis("ScaLAPACK: 2.2.0")

local hpc_root = os.getenv("TINYHPC_ROOT") or "/opt/hpc"
local root = pathJoin(hpc_root, "software/openmx/" .. version)

depends_on("gcc/9.5.0")
depends_on("openmpi/5.0.8-gcc9")
depends_on("openblas/0.3.30-gcc9")
depends_on("fftw/3.3.10-gcc9")
depends_on("scalapack/2.2.0-gcc9")

prepend_path("PATH", pathJoin(root, "bin"))
setenv("OPENMX_ROOT", root)
setenv("OPENMX_DATA", pathJoin(root, "DFT_DATA19"))
setenv("OPENMX_WORK", pathJoin(root, "work"))
