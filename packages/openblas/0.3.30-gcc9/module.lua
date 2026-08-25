local version = myModuleVersion()
help("OpenBLAS " .. version .. " built with GCC 9.5.0")
whatis("Name: OpenBLAS")
whatis("Version: " .. version)
whatis("Compiler: GCC 9.5.0")

local hpc_root = os.getenv("TINYHPC_ROOT") or "/opt/hpc"
local root = pathJoin(hpc_root, "software/openblas/" .. version)
depends_on("gcc/9.5.0")

prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
setenv("OPENBLAS_ROOT", root)
setenv("BLAS_ROOT", root)
setenv("LAPACK_ROOT", root)
