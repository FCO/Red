#!/usr/bin/env python3
"""List extracted dependency roots for compiler-independent source loading."""

import json
import os
from pathlib import Path
import sys


directories = []
for current, children, files in os.walk(sys.argv[1]):
    if "META6.json" not in files:
        continue
    root = Path(current).resolve()
    metadata = json.loads((root / "META6.json").read_text())
    # Dependency archives can contain fixture distributions: don't load those.
    children.clear()
    if not metadata.get("provides"):
        continue
    library = root / "lib"
    directories.append(str(library if library.is_dir() else root))

if not directories:
    sys.exit("No dependency sources were extracted")
Path(sys.argv[2]).write_text(json.dumps(sorted(set(directories)), indent=2) + "\n")
print(f"Prepared {len(set(directories))} dependency source directories")
