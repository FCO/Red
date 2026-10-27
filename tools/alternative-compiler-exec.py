#!/usr/bin/env python3
"""Run one TAP file with source dependencies and a bounded execution time."""

import json
import os
from pathlib import Path
import signal
import subprocess
import sys


def main():
    compiler, *arguments = sys.argv[1:]
    command = [compiler, "-Ilib"]
    manifest = os.environ.get("ALT_COMPILER_DEPENDENCIES")
    if manifest:
        for directory in json.loads(Path(manifest).read_text()):
            command.append("-I" + directory)
    command.extend(arguments)
    seconds = float(os.environ.get("ALT_COMPILER_TEST_TIMEOUT", "30"))
    if seconds <= 0:
        raise ValueError("ALT_COMPILER_TEST_TIMEOUT must be positive")
    process = subprocess.Popen(command, start_new_session=True)
    try:
        return process.wait(timeout=seconds)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        print(f"TIMEOUT: {compiler} {' '.join(arguments)} after {seconds:g}s",
              file=sys.stderr, flush=True)
        return 124


if __name__ == "__main__":
    sys.exit(main())
