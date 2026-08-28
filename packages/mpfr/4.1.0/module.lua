local version = myModuleVersion()
help("MPFR " .. version)
whatis("Name: MPFR")
whatis("Version: " .. version)

local hpc_root = os.getenv("TINYHPC_ROOT") or "/opt/hpc"
local root = pathJoin(hpc_root, "software/mpfr/" .. version)
depends_on("gmp/6.1.0")

prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
setenv("MPFR_ROOT", root)
