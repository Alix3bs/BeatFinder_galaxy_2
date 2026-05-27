from __future__ import annotations

import subprocess
import sys
import os
import tempfile
from pathlib import Path


def run(command: list[str], *, cwd: Path) -> None:
    env = {
        **os.environ,
        "PYTHONPYCACHEPREFIX": os.getenv(
            "PYTHONPYCACHEPREFIX",
            str(Path(tempfile.gettempdir()) / "beatfinder_pycache"),
        ),
    }
    completed = subprocess.run(command, cwd=cwd, env=env, check=False)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    python_executable = os.getenv("BEATFINDER_PYTHON_BIN") or str(Path(sys.executable))
    node_executable = os.getenv("BEATFINDER_NODE_BIN") or "node"

    run([python_executable, "-m", "compileall", "backend", "models", "scripts"], cwd=repo_root)
    run([node_executable, "--experimental-strip-types", "--check", "backend/api/server.ts"], cwd=repo_root)
    run(
        [node_executable, "--experimental-strip-types", "--test", "backend/api/request_parsers.test.ts"],
        cwd=repo_root,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
