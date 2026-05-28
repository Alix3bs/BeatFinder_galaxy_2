from __future__ import annotations

import subprocess
import sys
import os
import shutil
import tempfile
from pathlib import Path


def resolve_node_executable() -> str:
    configured_node = os.getenv("BEATFINDER_NODE_BIN")
    if configured_node:
        return configured_node

    path_node = shutil.which("node")
    if path_node:
        return path_node

    candidate_paths = [
        Path("/Applications/Codex.app/Contents/Resources/node"),
        Path.home() / ".cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node",
    ]
    for candidate_path in candidate_paths:
        if candidate_path.exists() and os.access(candidate_path, os.X_OK):
            return str(candidate_path)

    raise SystemExit(
        "Node.js was not found. Install Node or set BEATFINDER_NODE_BIN to a node executable."
    )


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
    node_executable = resolve_node_executable()

    run([python_executable, "-m", "compileall", "backend", "memory", "models", "scripts"], cwd=repo_root)
    run([node_executable, "--experimental-strip-types", "--check", "backend/api/server.ts"], cwd=repo_root)
    run(
        [node_executable, "--experimental-strip-types", "--test", "backend/api/request_parsers.test.ts"],
        cwd=repo_root,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
