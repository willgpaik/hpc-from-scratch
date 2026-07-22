whatis("Name: OpenMPI")
whatis("Version: 5.0.9")
whatis("URL: https://www.open-mpi.org/")

local version = "5.0.9"
local base    = pathJoin("/shared/sw/openmpi",version)
depends_on("gcc/12.5.0")
prepend_path("PATH", pathJoin(base,"bin"))
prepend_path("CPATH", pathJoin(base,"include"))
prepend_path("LD_LIBRARY_PATH", pathJoin(base,"lib"))
