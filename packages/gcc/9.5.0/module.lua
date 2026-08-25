local version = myModuleVersion()
help("GCC " .. version)
whatis("Name: GCC")
whatis("Version: " .. version)

local hpc_root = os.getenv("TINYHPC_ROOT") or "/opt/hpc"
local root = pathJoin(hpc_root, "software/gcc/" .. version)
depends_on("gmp/6.1.0")
depends_on("mpfr/4.1.0")
depends_on("mpc/1.2.1")

prepend_path("PATH", pathJoin(root, "bin"))
-- Do not prepend GCC runtime libraries to LD_LIBRARY_PATH here.
-- Loading an older GCC must not replace libstdc++ for the user shell or
-- unrelated host tools. The compiler driver finds its own link libraries;
-- recipes that require a specific runtime path should encode an rpath.
prepend_path("LIBRARY_PATH", pathJoin(root, "lib64"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("MANPATH", pathJoin(root, "share/man"))

setenv("CC", pathJoin(root, "bin/gcc"))
setenv("CXX", pathJoin(root, "bin/g++"))
setenv("FC", pathJoin(root, "bin/gfortran"))
setenv("GCC_ROOT", root)
