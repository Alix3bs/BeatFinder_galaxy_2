from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def run(command: list[str], *, cwd: Path) -> None:
    completed = subprocess.run(command, cwd=cwd, check=False)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    bundled_python = Path(
        "/Users/traytray/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
    )
    bundled_node = Path(
        "/Users/traytray/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
    )
    python_executable = str(bundled_python if bundled_python.exists() else Path(sys.executable))
    node_executable = str(bundled_node if bundled_node.exists() else "node")

    run([python_executable, "-m", "compileall", "backend", "models", "scripts"], cwd=repo_root)
    run([node_executable, "--experimental-strip-types", "--check", "backend/api/server.ts"], cwd=repo_root)
    run(
        [node_executable, "--experimental-strip-types", "--test", "backend/api/request_parsers.test.ts"],
        cwd=repo_root,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
