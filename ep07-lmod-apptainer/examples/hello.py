import platform
import sys

print(f"Running inside Apptainer container")
print(f"Python: {sys.version.split()[0]}")
print(f"Hostname: {platform.node()}")
