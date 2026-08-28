local version = myModuleVersion()
help("GMP " .. version)
whatis("Name: GMP")
whatis("Version: " .. version)

local hpc_root = os.getenv("TINYHPC_ROOT") or "/opt/hpc"
local root = pathJoin(hpc_root, "software/gmp/" .. version)

prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
setenv("GMP_ROOT", root)
