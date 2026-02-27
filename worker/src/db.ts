import { Pool } from "pg";
import type { WorkerConfig } from "./config.js";
import type { Candidate, MatchInsertRow, MatchRow, ResultState, SearchJob, SearchJobPayload } from "./types.js";

type SearchJobRow = Omit<SearchJob, "payload"> & { payload: unknown };

export class WorkerDb {
  private readonly pool: Pool;
  private readonly beatsUrlColumn: "source_url" | "url";

  constructor(config: WorkerConfig) {
    this.pool = new Pool({
      connectionString: config.supabaseDbUrl,
      max: 8,
    });
    this.beatsUrlColumn = config.beatsUrlColumn;
  }

  async close(): Promise<void> {
    await this.pool.end();
  }

  async claimNextJob(): Promise<SearchJob | null> {
    const sql = `
      with picked as (
        select id
        from public.search_jobs
        where status = 'pending'
        order by created_at asc
        for update skip locked
        limit 1
      )
      update public.search_jobs j
      set status = 'processing'
      from picked
      where j.id = picked.id
      returning j.id, j.search_id, j.user_id, j.query_type, j.query_text, j.payload, j.created_at
    `;

    const result = await this.pool.query<SearchJobRow>(sql);
    if (!result.rowCount) return null;

    const row = result.rows[0];
    return {
      id: row.id,
      search_id: row.search_id,
      user_id: row.user_id,
      query_type: row.query_type,
      query_text: row.query_text,
      payload: readPayload(row.payload),
      created_at: row.created_at,
    };
  }

  async markJobCompleted(jobId: string, resultState: ResultState, matchCount: number): Promise<void> {
    const sql = `
      update public.search_jobs
      set
        status = 'completed',
        payload = jsonb_set(
          jsonb_set(
            coalesce(payload, '{}'::jsonb),
            '{result_state}',
            to_jsonb($2::text),
            true
          ),
          '{processed_match_count}',
          to_jsonb($3::int),
          true
        )
      where id = $1
    `;
    await this.pool.query(sql, [jobId, resultState, matchCount]);
  }

  async markJobFailed(jobId: string, errorMessage: string): Promise<void> {
    // Required null-safe payload update.
    const sql = `
      update public.search_jobs
      set
        status = 'failed',
        payload = jsonb_set(
          coalesce(payload, '{}'::jsonb),
          '{error}',
          to_jsonb($2::text),
          true
        )
      where id = $1
    `;
    await this.pool.query(sql, [jobId, errorMessage]);
  }

  async insertMatches(rows: MatchInsertRow[]): Promise<MatchRow[]> {
    if (!rows.length) return [];

    const values: Array<string | number | null> = [];
    const tuples = rows.map((row, index) => {
      const offset = index * 8;
      values.push(
        row.search_id,
        row.user_id,
        row.platform,
        row.url,
        row.title,
        row.similarity,
        row.bpm,
        row.key,
      );
      return `($${offset + 1}, $${offset + 2}, $${offset + 3}, $${offset + 4}, $${offset + 5}, $${offset + 6}, $${offset + 7}, $${offset + 8})`;
    });

    const sql = `
      insert into public.matches (search_id, user_id, platform, url, title, similarity, bpm, key)
      values ${tuples.join(",\n")}
      returning id, search_id, user_id, platform, url, title, similarity, bpm, key, created_at
    `;

    const result = await this.pool.query<MatchRow>(sql, values);
    return result.rows;
  }

  async insertSavedMatch(userId: string, matchId: string): Promise<void> {
    const sql = `
      insert into public.saved_matches (user_id, match_id)
      values ($1, $2)
      on conflict do nothing
    `;
    await this.pool.query(sql, [userId, matchId]);
  }

  async ensureBeat(candidate: Candidate, userId: string): Promise<string> {
    const selectSql = `
      select id
      from public.beats
      where ${this.beatsUrlColumn} = $1
      limit 1
    `;
    const existing = await this.pool.query<{ id: string }>(selectSql, [candidate.url]);
    const existingId = existing.rows[0]?.id;
    if (existingId) return existingId;

    const insertSql = `
      insert into public.beats (user_id, platform, title, ${this.beatsUrlColumn}, bpm, key)
      values ($1, $2, $3, $4, $5, $6)
      returning id
    `;
    const inserted = await this.pool.query<{ id: string }>(insertSql, [
      userId,
      candidate.platform,
      candidate.title,
      candidate.url,
      candidate.bpm ?? null,
      candidate.key ?? null,
    ]);
    return inserted.rows[0].id;
  }

  async insertBeatFingerprint(beatId: string, fingerprintHash: string): Promise<void> {
    const sql = `
      insert into public.beat_fingerprints (beat_id, fingerprint_hash)
      values ($1, $2)
      on conflict do nothing
    `;
    await this.pool.query(sql, [beatId, fingerprintHash]);
  }
}

function readPayload(value: unknown): SearchJobPayload | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as SearchJobPayload;
}
