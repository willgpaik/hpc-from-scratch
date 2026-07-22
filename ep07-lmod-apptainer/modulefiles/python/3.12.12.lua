whatis("Name: Python")
whatis("Version: 3.12.12")
whatis("URL: https://www.python.org/")

local version = "3.12.12"
local base    = pathJoin("/shared/sw/python",version)
prepend_path("PATH", pathJoin(base,"bin"))
prepend_path("CPATH", pathJoin(base,"include"))
prepend_path("LD_LIBRARY_PATH", pathJoin(base,"lib"))
