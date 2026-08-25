local version = myModuleVersion()
help("ScaLAPACK " .. version .. " built with OpenMPI 5.0.8 and OpenBLAS 0.3.30")
whatis("Name: ScaLAPACK")
whatis("Version: " .. version)
whatis("Compiler: GCC 9.5.0")
whatis("MPI: OpenMPI 5.0.8")
whatis("BLAS/LAPACK: OpenBLAS 0.3.30")

local hpc_root = os.getenv("TINYHPC_ROOT") or "/opt/hpc"
local root = pathJoin(hpc_root, "software/scalapack/" .. version)

depends_on("gcc/9.5.0")
depends_on("openmpi/5.0.8-gcc9")
depends_on("openblas/0.3.30-gcc9")

prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
setenv("SCALAPACK_ROOT", root)
