import type { ResultState } from "./types.js";

type BeatsUrlColumn = "source_url" | "url";

export interface WorkerConfig {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  supabaseDbUrl: string;
  audioBucket: string;
  embedQueryFunctionName: string;
  fingerprintFunctionName: string;
  embedBeatFunctionName: string;
  enableDirectEmbedCalls: boolean;
  pollIntervalMs: number;
  matchLimit: number;
  persistTopMatches: number;
  exactThreshold: number;
  closeThreshold: number;
  beatsUrlColumn: BeatsUrlColumn;
  defaultResultState: ResultState;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): WorkerConfig {
  const exactThreshold = readNumber(env.WORKER_EXACT_THRESHOLD, 0.9);
  const closeThreshold = readNumber(env.WORKER_CLOSE_THRESHOLD, 0.6);
  if (closeThreshold > exactThreshold) {
    throw new Error("WORKER_CLOSE_THRESHOLD cannot be greater than WORKER_EXACT_THRESHOLD.");
  }

  const beatsUrlColumn = readBeatsUrlColumn(env.BEATS_URL_COLUMN);

  return {
    supabaseUrl: readRequired(env.SUPABASE_URL),
    supabaseServiceRoleKey: readRequired(env.SUPABASE_SERVICE_ROLE_KEY),
    supabaseDbUrl: readRequired(env.SUPABASE_DB_URL),
    audioBucket: env.SUPABASE_AUDIO_BUCKET ?? "search-audio",
    embedQueryFunctionName: env.SUPABASE_EMBED_QUERY_FUNCTION ?? "embed_query",
    fingerprintFunctionName: env.SUPABASE_FINGERPRINT_FUNCTION ?? "fingerprint",
    embedBeatFunctionName: env.SUPABASE_EMBED_BEAT_FUNCTION ?? "embed",
    enableDirectEmbedCalls: readBoolean(env.WORKER_ENABLE_DIRECT_EMBED_CALLS, false),
    pollIntervalMs: readNumber(env.WORKER_POLL_INTERVAL_MS, 1200),
    matchLimit: readNumber(env.WORKER_MATCH_LIMIT, 20),
    persistTopMatches: readNumber(env.WORKER_PERSIST_TOP_MATCHES, 10),
    exactThreshold,
    closeThreshold,
    beatsUrlColumn,
    defaultResultState: "not_found",
  };
}

function readRequired(value: string | undefined): string {
  if (!value || !value.trim()) {
    throw new Error("Missing required environment variable.");
  }
  return value.trim();
}

function readNumber(value: string | undefined, fallback: number): number {
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Invalid numeric environment value: ${value}`);
  }
  return parsed;
}

function readBoolean(value: string | undefined, fallback: boolean): boolean {
  if (!value) return fallback;
  const normalized = value.trim().toLowerCase();
  if (["1", "true", "yes", "y"].includes(normalized)) return true;
  if (["0", "false", "no", "n"].includes(normalized)) return false;
  throw new Error(`Invalid boolean environment value: ${value}`);
}

function readBeatsUrlColumn(value: string | undefined): BeatsUrlColumn {
  if (!value) return "source_url";
  if (value === "source_url" || value === "url") return value;
  throw new Error("BEATS_URL_COLUMN must be either 'source_url' or 'url'.");
}
