whatis("Name: GCC")
whatis("Version: 12.5.0")
whatis("URL: https://gcc.gnu.org/")

local version = "12.5.0"
local base    = pathJoin("/shared/sw/gcc",version)
prepend_path("PATH", pathJoin(base,"bin"))
prepend_path("CPATH", pathJoin(base,"include"))
prepend_path("LD_LIBRARY_PATH", pathJoin(base,"lib64"))
