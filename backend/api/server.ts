import http, { type IncomingMessage, type ServerResponse } from "node:http";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

import { readRequestPayload } from "./request_parsers.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "..", "..");
const pythonBin = process.env.BEATFINDER_PYTHON_BIN || "python3";
const port = Number(process.env.PORT || "8787");
const stateDir = process.env.BEATFINDER_STATE_DIR || resolve(repoRoot, ".beatfinder_state");

const routeMap = new Map<string, string>([
  ["POST /ingest/beat", "ingest"],
  ["POST /search/text", "search-text"],
  ["POST /search/audio", "search-audio"],
  ["POST /search/hybrid", "search-hybrid"],
  ["POST /feedback", "feedback"],
]);

const server = http.createServer(async (req, res) => {
  setJsonHeaders(res);

  if (req.method === "OPTIONS") {
    res.statusCode = 204;
    res.end();
    return;
  }

  if (req.method === "GET" && req.url === "/health") {
    await handleHealth(res);
    return;
  }

  const routeKey = `${req.method || "GET"} ${req.url || "/"}`;
  const command = routeMap.get(routeKey);
  if (!command) {
    sendJson(res, 404, { error: "not_found" });
    return;
  }

  try {
    const payload = await readRequestPayload(req);
    const result = await runCli(command, payload);
    sendJson(res, 200, result);
  } catch (error) {
    sendJson(res, classifyError(error), {
      error: "server_error",
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

server.listen(port, () => {
  console.log(JSON.stringify({ status: "listening", port, stateDir }));
});

async function handleHealth(res: ServerResponse): Promise<void> {
  try {
    const health = await runCli("health", {});
    sendJson(res, 200, health);
  } catch (error) {
    sendJson(res, 500, {
      error: "health_check_failed",
      message: error instanceof Error ? error.message : String(error),
    });
  }
}

function setJsonHeaders(res: ServerResponse): void {
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

function sendJson(res: ServerResponse, statusCode: number, payload: unknown): void {
  res.statusCode = statusCode;
  res.end(JSON.stringify(payload));
}

function classifyError(error: unknown): number {
  const message = error instanceof Error ? error.message : String(error);
  if (/invalid json/i.test(message) || /missing a boundary/i.test(message)) {
    return 400;
  }
  if (/required/i.test(message) || /audio_path.*required/i.test(message)) {
    return 400;
  }
  return 500;
}

function runCli(command: string, payload: Record<string, unknown>): Promise<Record<string, unknown>> {
  return new Promise((resolveResult, reject) => {
    const child = spawn(
      pythonBin,
      ["-m", "backend.workers.cli", command, "--state-dir", stateDir],
      {
        cwd: repoRoot,
        env: {
          ...process.env,
          PYTHONUNBUFFERED: "1",
        },
      },
    );

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString("utf8");
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString("utf8");
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(stderr || stdout || `CLI exited with code ${code}`));
        return;
      }
      try {
        resolveResult(JSON.parse(stdout || "{}") as Record<string, unknown>);
      } catch (error) {
        reject(
          new Error(
            `CLI returned invalid JSON: ${error instanceof Error ? error.message : String(error)}\n${stdout}`,
          ),
        );
      }
    });

    child.stdin.write(JSON.stringify(payload || {}));
    child.stdin.end();
  });
}
