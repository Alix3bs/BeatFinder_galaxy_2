from __future__ import annotations

import json
import os
import socket
import subprocess
import tempfile
import time
import unittest
import uuid
from pathlib import Path
from urllib.request import Request, urlopen

from backend.tests.fixture_builder import materialize_fixtures

NODE_BIN = "/Users/traytray/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
PYTHON_BIN = "/Users/traytray/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"


class ApiSmokeTests(unittest.TestCase):
    def test_health_ingest_and_search_endpoints(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(__file__).resolve().parents[2]
            fixtures = materialize_fixtures(Path(temp_dir) / "fixtures")
            try:
                port = find_free_port()
            except PermissionError as error:
                self.skipTest(f"Socket binding is blocked in this environment: {error}")
            env = {
                **os.environ,
                "PORT": str(port),
                "BEATFINDER_PYTHON_BIN": PYTHON_BIN,
                "BEATFINDER_STATE_DIR": str(Path(temp_dir) / "state"),
            }

            server = subprocess.Popen(
                [NODE_BIN, "--experimental-strip-types", str(repo_root / "backend" / "api" / "server.ts")],
                cwd=repo_root,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                wait_for_health(port)

                health = request_json(f"http://127.0.0.1:{port}/health")
                self.assertEqual(health["status"], "ok")

                ingest_response = request_json(
                    f"http://127.0.0.1:{port}/ingest/beat",
                    method="POST",
                    payload=fixtures[0],
                )
                self.assertEqual(ingest_response["status"], "ingested")

                multipart_response = request_multipart(
                    f"http://127.0.0.1:{port}/search/hybrid",
                    fields={
                        "query": "sza x summer walker type beat",
                        "top_n": "3",
                    },
                    file_field="audio",
                    file_name="late_nights.wav",
                    file_bytes=Path(fixtures[0]["audio_path"]).read_bytes(),
                    mime_type="audio/wav",
                )
                self.assertTrue(multipart_response["results"])
                self.assertEqual(multipart_response["results"][0]["beat"]["raw_title"], fixtures[0]["title"])

                search_response = request_json(
                    f"http://127.0.0.1:{port}/search/text",
                    method="POST",
                    payload={"query": "sza type beat", "top_n": 3},
                )
                self.assertTrue(search_response["results"])
                self.assertIn("score_breakdown", search_response["results"][0])
            finally:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()


def request_json(url: str, *, method: str = "GET", payload: dict[str, object] | None = None) -> dict[str, object]:
    body = json.dumps(payload or {}).encode("utf-8")
    request = Request(url, data=body if method != "GET" else None, method=method)
    request.add_header("Content-Type", "application/json")
    with urlopen(request, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def wait_for_health(port: int, timeout_seconds: float = 10.0) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        try:
            request_json(f"http://127.0.0.1:{port}/health")
            return
        except Exception:
            time.sleep(0.25)
    raise AssertionError(f"Server on port {port} did not become healthy in time.")


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def request_multipart(
    url: str,
    *,
    fields: dict[str, str],
    file_field: str,
    file_name: str,
    file_bytes: bytes,
    mime_type: str,
) -> dict[str, object]:
    boundary = f"beatfinder-{uuid.uuid4().hex}"
    chunks: list[bytes] = []
    for key, value in fields.items():
        chunks.extend(
            [
                f"--{boundary}\r\n".encode("utf-8"),
                f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode("utf-8"),
                str(value).encode("utf-8"),
                b"\r\n",
            ]
        )
    chunks.extend(
        [
            f"--{boundary}\r\n".encode("utf-8"),
            (
                f'Content-Disposition: form-data; name="{file_field}"; filename="{file_name}"\r\n'
                f"Content-Type: {mime_type}\r\n\r\n"
            ).encode("utf-8"),
            file_bytes,
            b"\r\n",
            f"--{boundary}--\r\n".encode("utf-8"),
        ]
    )
    request = Request(url, data=b"".join(chunks), method="POST")
    request.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    with urlopen(request, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


if __name__ == "__main__":
    unittest.main()
