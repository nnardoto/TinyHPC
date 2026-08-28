local version = myModuleVersion()
help("MPC " .. version)
whatis("Name: MPC")
whatis("Version: " .. version)

local hpc_root = os.getenv("TINYHPC_ROOT") or "/opt/hpc"
local root = pathJoin(hpc_root, "software/mpc/" .. version)
depends_on("gmp/6.1.0")
depends_on("mpfr/4.1.0")

prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
setenv("MPC_ROOT", root)
