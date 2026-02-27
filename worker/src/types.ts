export type QueryType = "text" | "audio";

export type ResultState = "exact_match" | "close_matches" | "not_found";

export interface SearchJobPayload {
  query?: string;
  save_top_match?: boolean;
  target_bpm?: number;
  target_key?: string;
  audio_base64?: string;
  audio_file_name?: string;
  audio_mime_type?: string;
  audio_storage_path?: string;
  audio_url?: string;
  [key: string]: unknown;
}

export interface SearchJob {
  id: string;
  search_id: string | null;
  user_id: string;
  query_type: QueryType;
  query_text: string | null;
  payload: SearchJobPayload | null;
  created_at: string;
}

export interface Candidate {
  beat_id?: string | null;
  platform: string;
  url: string;
  title: string;
  bpm?: number | null;
  key?: string | null;
  similarity?: number | null;
  producer_tag_score?: number | null;
  semantic_score?: number | null;
  tempo_score?: number | null;
  key_score?: number | null;
  fingerprint_hash?: string | null;
}

export interface RankedCandidate {
  candidate: Candidate;
  finalScore: number;
}

export interface MatchInsertRow {
  search_id: string;
  user_id: string;
  platform: string;
  url: string;
  title: string;
  similarity: number;
  bpm: number | null;
  key: string | null;
}

export interface MatchRow extends MatchInsertRow {
  id: string;
  created_at: string;
}

export interface RpcBeatRow {
  beat_id?: string | null;
  platform?: string | null;
  url?: string | null;
  source_url?: string | null;
  title?: string | null;
  bpm?: number | null;
  key?: string | null;
  similarity?: number | null;
  producer_tag_score?: number | null;
  semantic_score?: number | null;
  tempo_score?: number | null;
  key_score?: number | null;
}
