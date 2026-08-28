local version = myModuleVersion()
help("OpenMPI " .. version .. " built with GCC 9.5.0")
whatis("Name: OpenMPI")
whatis("Version: " .. version)
whatis("Compiler: GCC 9.5.0")

local hpc_root = os.getenv("TINYHPC_ROOT") or "/opt/hpc"
local root = pathJoin(hpc_root, "software/openmpi/" .. version)
depends_on("gcc/9.5.0")

prepend_path("PATH", pathJoin(root, "bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("MANPATH", pathJoin(root, "share/man"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
setenv("MPI_ROOT", root)
