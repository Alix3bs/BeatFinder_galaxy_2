import http, { type IncomingMessage, type ServerResponse } from "node:http";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

import { FixedWindowRateLimiter, clientKeyFromHeaders } from "./rate_limit.ts";
import { PayloadTooLargeError, readRequestPayload } from "./request_parsers.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "..", "..");
const pythonBin = process.env.BEATFINDER_PYTHON_BIN || "python3";
const port = Number(process.env.PORT || "8787");
const stateDir = process.env.BEATFINDER_STATE_DIR || resolve(repoRoot, ".beatfinder_state");

const DEFAULT_MAX_UPLOAD_BYTES = 25 * 1024 * 1024;
const DEFAULT_CLI_TIMEOUT_MS = 120_000;

const maxUploadBytes = parsePositiveInt(process.env.BEATFINDER_MAX_UPLOAD_BYTES, DEFAULT_MAX_UPLOAD_BYTES);
const cliTimeoutMs = parsePositiveInt(process.env.BEATFINDER_CLI_TIMEOUT_MS, DEFAULT_CLI_TIMEOUT_MS);
const allowLocalAudioPaths = ["1", "true", "yes"].includes(
  String(process.env.BEATFINDER_ALLOW_LOCAL_AUDIO_PATHS || "").trim().toLowerCase(),
);

// Audio processing is the expensive path; text search is cheap by
// comparison but still bounded. 0 disables the limiter (e.g. local dev).
const rateLimitPerMinute = parseNonNegativeInt(process.env.BEATFINDER_RATE_LIMIT_PER_MINUTE, 30);
const expensiveRouteLimiter = new FixedWindowRateLimiter({
  limit: rateLimitPerMinute,
  windowMs: 60_000,
});
const EXPENSIVE_ROUTES = new Set(["POST /search/audio", "POST /search/hybrid", "POST /ingest/beat"]);

const routeMap = new Map<string, string>([
  ["POST /ingest/beat", "ingest"],
  ["POST /search/text", "search-text"],
  ["POST /search/audio", "search-audio"],
  ["POST /search/hybrid", "search-hybrid"],
  ["POST /feedback", "feedback"],
]);

class CliClientError extends Error {
  code: string;
  httpStatus: number;

  constructor(code: string, message: string, httpStatus: number) {
    super(message);
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

class CliTimeoutError extends Error {}

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
    sendJson(res, 404, { error: "not_found", message: "Unknown endpoint." });
    return;
  }

  if (EXPENSIVE_ROUTES.has(routeKey)) {
    const clientKey = clientKeyFromHeaders(
      req.socket.remoteAddress ?? undefined,
      typeof req.headers["x-forwarded-for"] === "string" ? req.headers["x-forwarded-for"] : undefined,
    );
    if (!expensiveRouteLimiter.allow(clientKey)) {
      res.setHeader("Retry-After", "60");
      sendJson(res, 429, {
        error: "rate_limited",
        message: "Too many requests. Try again in a minute.",
      });
      return;
    }
  }

  const contentType = String(req.headers["content-type"] || "");
  if (contentType && !isSupportedContentType(contentType)) {
    sendJson(res, 415, {
      error: "unsupported_content_type",
      message: "Send application/json or multipart/form-data.",
    });
    return;
  }

  try {
    const payload = await readRequestPayload(req, { maxBytes: maxUploadBytes });
    if (!allowLocalAudioPaths && hasLocalAudioPath(payload)) {
      sendJson(res, 400, {
        error: "audio_path_not_allowed",
        message: "audio_path is not accepted over HTTP. Upload the audio file instead.",
      });
      return;
    }
    const result = await runCli(command, payload);
    sendJson(res, 200, result);
  } catch (error) {
    sendErrorResponse(res, error);
  }
});

server.listen(port, () => {
  console.log(
    JSON.stringify({
      status: "listening",
      port,
      stateDir,
      maxUploadBytes,
      cliTimeoutMs,
      allowLocalAudioPaths,
    }),
  );
});

let shuttingDown = false;
for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.on(signal, () => {
    if (shuttingDown) {
      process.exit(1);
    }
    shuttingDown = true;
    console.log(JSON.stringify({ status: "shutting_down", signal }));
    server.close(() => {
      process.exit(0);
    });
    setTimeout(() => process.exit(0), 10_000).unref();
  });
}

async function handleHealth(res: ServerResponse): Promise<void> {
  try {
    const health = await runCli("health", {});
    sendJson(res, 200, health);
  } catch (error) {
    logServerError(error);
    sendJson(res, 500, {
      error: "health_check_failed",
      message: "BeatFinder backend health check failed.",
    });
  }
}

function isSupportedContentType(contentType: string): boolean {
  const normalized = contentType.toLowerCase();
  return normalized.includes("application/json") || normalized.includes("multipart/form-data");
}

function hasLocalAudioPath(payload: Record<string, unknown>): boolean {
  const value = payload["audio_path"];
  return typeof value === "string" && value.trim().length > 0;
}

function setJsonHeaders(res: ServerResponse): void {
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Access-Control-Allow-Origin", process.env.BEATFINDER_CORS_ORIGIN || "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

function sendJson(res: ServerResponse, statusCode: number, payload: unknown): void {
  res.statusCode = statusCode;
  res.end(JSON.stringify(payload));
}

function sendErrorResponse(res: ServerResponse, error: unknown): void {
  if (error instanceof PayloadTooLargeError) {
    sendJson(res, 413, {
      error: "upload_too_large",
      message: `Request body exceeds the ${maxUploadBytes} byte limit.`,
    });
    return;
  }
  if (error instanceof CliClientError) {
    sendJson(res, error.httpStatus, { error: error.code, message: error.message });
    return;
  }
  if (error instanceof CliTimeoutError) {
    sendJson(res, 504, {
      error: "processing_timeout",
      message: "The BeatFinder backend took too long to process this request.",
    });
    return;
  }
  const message = error instanceof Error ? error.message : String(error);
  if (/invalid json/i.test(message) || /unexpected token/i.test(message) || /missing a boundary/i.test(message)) {
    sendJson(res, 400, { error: "invalid_request_body", message: "Request body could not be parsed." });
    return;
  }
  logServerError(error);
  sendJson(res, 500, {
    error: "internal_error",
    message: "BeatFinder backend hit an internal error.",
  });
}

function logServerError(error: unknown): void {
  console.error(
    JSON.stringify({
      status: "request_error",
      message: error instanceof Error ? error.message : String(error),
    }),
  );
}

function parsePositiveInt(rawValue: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(String(rawValue || "").trim(), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function parseNonNegativeInt(rawValue: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(String(rawValue || "").trim(), 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
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
    let timedOut = false;

    const timeout = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, cliTimeoutMs);

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString("utf8");
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString("utf8");
    });
    child.on("error", (error) => {
      clearTimeout(timeout);
      reject(error);
    });
    child.on("close", (code) => {
      clearTimeout(timeout);
      if (timedOut) {
        reject(new CliTimeoutError());
        return;
      }
      if (code === 4) {
        reject(parseCliClientError(stdout));
        return;
      }
      if (code !== 0) {
        if (stderr.trim()) {
          console.error(JSON.stringify({ status: "cli_error", command, detail: stderr.slice(0, 4000) }));
        }
        reject(new Error(`CLI exited with code ${code}`));
        return;
      }
      try {
        resolveResult(JSON.parse(stdout || "{}") as Record<string, unknown>);
      } catch (error) {
        reject(
          new Error(
            `CLI returned invalid JSON: ${error instanceof Error ? error.message : String(error)}`,
          ),
        );
      }
    });

    child.stdin.write(JSON.stringify(payload || {}));
    child.stdin.end();
  });
}

function parseCliClientError(stdout: string): CliClientError {
  try {
    const parsed = JSON.parse(stdout) as { error?: string; message?: string; http_status?: number };
    return new CliClientError(
      String(parsed.error || "invalid_request"),
      String(parsed.message || "Invalid request."),
      normalizeClientStatus(parsed.http_status),
    );
  } catch {
    return new CliClientError("invalid_request", "Invalid request.", 400);
  }
}

function normalizeClientStatus(status: unknown): number {
  const parsed = Number(status);
  return Number.isInteger(parsed) && parsed >= 400 && parsed < 500 ? parsed : 400;
}
