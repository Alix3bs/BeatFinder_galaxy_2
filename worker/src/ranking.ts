import type { Candidate, RankedCandidate, SearchJob } from "./types.js";

// producer_tag stays highest by design.
export const RANKING_WEIGHTS = {
  producer_tag: 0.45,
  semantic: 0.3,
  tempo: 0.15,
  key: 0.1,
} as const;

export function rankCandidates(candidates: Candidate[], job: SearchJob): RankedCandidate[] {
  return candidates
    .map((candidate) => ({
      candidate,
      finalScore: scoreCandidate(candidate, job),
    }))
    .sort((a, b) => b.finalScore - a.finalScore);
}

function scoreCandidate(candidate: Candidate, job: SearchJob): number {
  const semantic = clamp01(readNumber(candidate.semantic_score) ?? readNumber(candidate.similarity) ?? 0);
  const producerTag = clamp01(readNumber(candidate.producer_tag_score) ?? semantic);

  const targetBpm = readNumber(job.payload?.target_bpm);
  const tempo = clamp01(
    readNumber(candidate.tempo_score) ?? computeTempoScore(targetBpm, readNumber(candidate.bpm)) ?? semantic,
  );

  const targetKey = normalizeKey(job.payload?.target_key);
  const key = clamp01(
    readNumber(candidate.key_score) ?? computeKeyScore(targetKey, normalizeKey(candidate.key)) ?? semantic,
  );

  const weighted =
    producerTag * RANKING_WEIGHTS.producer_tag +
    semantic * RANKING_WEIGHTS.semantic +
    tempo * RANKING_WEIGHTS.tempo +
    key * RANKING_WEIGHTS.key;

  return clamp01(weighted);
}

function readNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function computeTempoScore(targetBpm: number | null, candidateBpm: number | null): number | null {
  if (!targetBpm || !candidateBpm) return null;
  const delta = Math.abs(targetBpm - candidateBpm);
  return 1 - Math.min(delta, 80) / 80;
}

function computeKeyScore(targetKey: string | null, candidateKey: string | null): number | null {
  if (!targetKey || !candidateKey) return null;
  return targetKey === candidateKey ? 1 : 0;
}

function normalizeKey(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  return normalized.length ? normalized : null;
}

function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}
