help([[MPC 1.0.3]])
whatis("Name: MPC")
whatis("Version: 1.0.3")

local hpc_root = os.getenv("TINYHPC_ROOT") or "/opt/hpc"
local root = pathJoin(hpc_root, "software/mpc/1.0.3")
depends_on("gmp/6.1.0")
depends_on("mpfr/4.1.0")

prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
setenv("MPC_ROOT", root)
