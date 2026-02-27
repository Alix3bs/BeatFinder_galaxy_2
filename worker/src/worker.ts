import { loadConfig } from "./config.js";
import { WorkerDb } from "./db.js";
import { rankCandidates } from "./ranking.js";
import { SupabaseApi } from "./supabase-api.js";
import type { Candidate, MatchInsertRow, ResultState, RpcBeatRow, SearchJob } from "./types.js";

const config = loadConfig();
const db = new WorkerDb(config);
const supabaseApi = new SupabaseApi(config);

let running = true;

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

runWorker().catch(async (error) => {
  console.error("Worker crashed:", toErrorMessage(error));
  await db.close();
  process.exit(1);
});

async function runWorker(): Promise<void> {
  console.log("BeatFinder worker started.");
  console.log(`Direct embed calls: ${config.enableDirectEmbedCalls ? "enabled" : "disabled (DB triggers expected)"}`);

  while (running) {
    const job = await db.claimNextJob();
    if (!job) {
      await sleep(config.pollIntervalMs);
      continue;
    }

    console.log(`Processing job ${job.id} (${job.query_type}) search_id=${job.search_id}`);

    if (!job.search_id) {
      await db.markJobFailed(job.id, "search_jobs.search_id is null; cannot insert into public.matches.");
      console.error(`Job ${job.id} failed: missing search_id`);
      continue;
    }
    const searchId = job.search_id;

    try {
      const candidates = await fetchCandidates(job);
      const ranked = rankCandidates(candidates, job).slice(0, config.persistTopMatches);

      const rowsToInsert: MatchInsertRow[] = [];
      for (const rankedCandidate of ranked) {
        const { candidate, finalScore } = rankedCandidate;

        let beatId = candidate.beat_id ?? null;
        if (!beatId) {
          beatId = await db.ensureBeat(candidate, job.user_id);
          if (candidate.fingerprint_hash) {
            await db.insertBeatFingerprint(beatId, candidate.fingerprint_hash);
          }
          if (config.enableDirectEmbedCalls) {
            await supabaseApi.triggerEmbedding(beatId, buildEmbeddingText(candidate));
          }
        }

        rowsToInsert.push({
          search_id: searchId, // Never use job.id for matches.search_id
          user_id: job.user_id,
          platform: candidate.platform,
          url: candidate.url,
          title: candidate.title,
          similarity: clamp01(finalScore),
          bpm: candidate.bpm ?? null,
          key: candidate.key ?? null,
        });
      }

      const insertedMatches = await db.insertMatches(rowsToInsert);
      const resultState = resolveResultState(insertedMatches.map((row) => row.similarity));

      if (job.payload?.save_top_match === true && insertedMatches[0]) {
        await db.insertSavedMatch(job.user_id, insertedMatches[0].id);
      }

      await db.markJobCompleted(job.id, resultState, insertedMatches.length);
      console.log(`Job ${job.id} complete. state=${resultState}, matches=${insertedMatches.length}`);
    } catch (error) {
      const message = toErrorMessage(error);
      await db.markJobFailed(job.id, message);
      console.error(`Job ${job.id} failed: ${message}`);
    }
  }

  await db.close();
  console.log("Worker stopped.");
}

async function fetchCandidates(job: SearchJob): Promise<Candidate[]> {
  if (job.query_type === "text") {
    return await fetchTextCandidates(job);
  }
  if (job.query_type === "audio") {
    return await fetchAudioCandidates(job);
  }
  throw new Error(`Unsupported query_type: ${job.query_type}`);
}

async function fetchTextCandidates(job: SearchJob): Promise<Candidate[]> {
  const query = readString(job.query_text) ?? readString(job.payload?.query);
  if (!query) {
    throw new Error("Text search job missing query_text.");
  }

  const embedding = await supabaseApi.embedQuery(query);
  const rows = await supabaseApi.searchByEmbedding({
    query_embedding: embedding,
    match_count: config.matchLimit,
  });

  return rows
    .map((row) => mapRpcRow(row as RpcBeatRow))
    .filter((candidate): candidate is Candidate => candidate !== null);
}

async function fetchAudioCandidates(job: SearchJob): Promise<Candidate[]> {
  const storagePath = await resolveAudioPath(job);
  const signedUrl = await supabaseApi.createSignedUrl(storagePath);
  const fingerprintHash = await supabaseApi.fingerprintAudio({ storagePath, signedUrl });

  const rows = await supabaseApi.searchByFingerprintHash({
    query_hash: fingerprintHash,
    match_count: config.matchLimit,
  });

  return rows
    .map((row) => mapRpcRow(row as RpcBeatRow, fingerprintHash))
    .filter((candidate): candidate is Candidate => candidate !== null);
}

async function resolveAudioPath(job: SearchJob): Promise<string> {
  const existingStoragePath = readString(job.payload?.audio_storage_path);
  if (existingStoragePath) {
    return existingStoragePath;
  }

  const objectPath = buildAudioObjectPath(job);
  const contentType = readString(job.payload?.audio_mime_type) ?? "audio/m4a";

  const audioBase64 = readString(job.payload?.audio_base64);
  if (audioBase64) {
    return await supabaseApi.uploadAudioFromBase64({
      base64: audioBase64,
      objectPath,
      contentType,
    });
  }

  const audioUrl = readString(job.payload?.audio_url);
  if (audioUrl) {
    return await supabaseApi.uploadAudioFromUrl({
      url: audioUrl,
      objectPath,
      contentType,
    });
  }

  throw new Error("Audio search job missing audio_storage_path, audio_base64, or audio_url.");
}

function mapRpcRow(row: RpcBeatRow, fingerprintHash?: string): Candidate | null {
  const platform = readString(row.platform);
  const url = readString(row.url) ?? readString(row.source_url);
  const title = readString(row.title);

  if (!platform || !url || !title) {
    return null;
  }

  return {
    beat_id: readString(row.beat_id),
    platform,
    url,
    title,
    bpm: readNumber(row.bpm),
    key: readString(row.key),
    similarity: clamp01(readNumber(row.similarity) ?? 0),
    producer_tag_score: clamp01(readNumber(row.producer_tag_score) ?? readNumber(row.similarity) ?? 0),
    semantic_score: clamp01(readNumber(row.semantic_score) ?? readNumber(row.similarity) ?? 0),
    tempo_score: readNumber(row.tempo_score),
    key_score: readNumber(row.key_score),
    fingerprint_hash: fingerprintHash ?? null,
  };
}

function resolveResultState(similarities: number[]): ResultState {
  if (!similarities.length) return config.defaultResultState;
  if (similarities.some((score) => score >= config.exactThreshold)) return "exact_match";
  if (similarities.some((score) => score >= config.closeThreshold)) return "close_matches";
  return "not_found";
}

function buildAudioObjectPath(job: SearchJob): string {
  const preferredFileName = readString(job.payload?.audio_file_name) ?? "query-audio.m4a";
  const searchIdFolder = job.search_id ?? job.id;
  return `search_jobs/${searchIdFolder}/${Date.now()}-${preferredFileName}`;
}

function buildEmbeddingText(candidate: Candidate): string {
  return [candidate.title, candidate.platform, candidate.key ?? "", candidate.bpm?.toString() ?? ""]
    .join(" ")
    .trim();
}

function readString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length ? trimmed : null;
}

function readNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  return JSON.stringify(error);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function shutdown(): Promise<void> {
  running = false;
}
