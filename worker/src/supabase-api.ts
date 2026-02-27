import { createClient } from "@supabase/supabase-js";
import type { WorkerConfig } from "./config.js";

export class SupabaseApi {
  private readonly client;

  constructor(private readonly config: WorkerConfig) {
    this.client = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
  }

  async embedQuery(query: string): Promise<number[]> {
    const response = await this.callEdge<Record<string, unknown>>(this.config.embedQueryFunctionName, { query });
    const embedding =
      readNumberArray(response.embedding) ??
      readNumberArray(readObject(response.data)?.embedding) ??
      readNumberArray(readObject(response.result)?.embedding);

    if (!embedding || embedding.length === 0) {
      throw new Error("embed_query returned no embedding.");
    }
    return embedding;
  }

  async fingerprintAudio(input: { storagePath: string; signedUrl: string }): Promise<string> {
    const response = await this.callEdge<Record<string, unknown>>(this.config.fingerprintFunctionName, {
      bucket: this.config.audioBucket,
      audio_path: input.storagePath,
      storage_path: input.storagePath,
      snippet_url: input.signedUrl,
      source_url: input.signedUrl,
    });

    const hash =
      readString(response.fingerprint_hash) ??
      readString(readObject(response.data)?.fingerprint_hash) ??
      readString(readObject(response.result)?.fingerprint_hash);

    if (!hash) {
      throw new Error("fingerprint function returned no fingerprint_hash.");
    }
    return hash;
  }

  async searchByEmbedding(params: {
    query_embedding: number[];
    match_count: number;
    min_similarity?: number;
  }): Promise<Array<Record<string, unknown>>> {
    return await this.callRpc<Array<Record<string, unknown>>>("search_beats_by_embedding", params);
  }

  async searchByFingerprintHash(params: {
    query_hash: string;
    match_count: number;
  }): Promise<Array<Record<string, unknown>>> {
    return await this.callRpc<Array<Record<string, unknown>>>("search_beats_by_fingerprint_hash", params);
  }

  async uploadAudioFromBase64(options: {
    base64: string;
    objectPath: string;
    contentType: string;
  }): Promise<string> {
    const binary = Buffer.from(options.base64, "base64");
    const { error } = await this.client.storage.from(this.config.audioBucket).upload(options.objectPath, binary, {
      contentType: options.contentType,
      upsert: true,
    });

    if (error) {
      throw new Error(`Storage upload failed: ${error.message}`);
    }
    return options.objectPath;
  }

  async uploadAudioFromUrl(options: {
    url: string;
    objectPath: string;
    contentType: string;
  }): Promise<string> {
    const response = await fetch(options.url);
    if (!response.ok) {
      throw new Error(`Failed downloading audio from ${options.url}: ${response.status} ${response.statusText}`);
    }

    const buffer = Buffer.from(await response.arrayBuffer());
    const { error } = await this.client.storage.from(this.config.audioBucket).upload(options.objectPath, buffer, {
      contentType: options.contentType,
      upsert: true,
    });

    if (error) {
      throw new Error(`Storage upload failed: ${error.message}`);
    }
    return options.objectPath;
  }

  async createSignedUrl(storagePath: string, seconds = 300): Promise<string> {
    const { data, error } = await this.client.storage
      .from(this.config.audioBucket)
      .createSignedUrl(storagePath, seconds);

    if (error || !data?.signedUrl) {
      throw new Error(`Failed creating signed URL for ${storagePath}: ${error?.message ?? "unknown error"}`);
    }
    return data.signedUrl;
  }

  async triggerEmbedding(beatId: string, text: string): Promise<void> {
    if (!this.config.enableDirectEmbedCalls) {
      return;
    }

    const payload = [
      {
        msg_id: beatId,
        message: {
          id: beatId,
          text,
        },
      },
    ];

    await this.callEdge<unknown>(this.config.embedBeatFunctionName, payload);
  }

  private async callEdge<T>(functionName: string, payload: unknown): Promise<T> {
    const response = await fetch(`${this.config.supabaseUrl}/functions/v1/${functionName}`, {
      method: "POST",
      headers: this.requestHeaders("application/json"),
      body: JSON.stringify(payload),
    });

    const body = await readJson(response);
    if (!response.ok) {
      throw new Error(`Edge function ${functionName} failed: ${response.status} ${JSON.stringify(body)}`);
    }
    return body as T;
  }

  private async callRpc<T>(rpcName: string, payload: unknown): Promise<T> {
    const response = await fetch(`${this.config.supabaseUrl}/rest/v1/rpc/${rpcName}`, {
      method: "POST",
      headers: this.requestHeaders("application/json"),
      body: JSON.stringify(payload),
    });

    const body = await readJson(response);
    if (!response.ok) {
      throw new Error(`RPC ${rpcName} failed: ${response.status} ${JSON.stringify(body)}`);
    }
    return (body ?? []) as T;
  }

  private requestHeaders(contentType: string): Record<string, string> {
    return {
      Authorization: `Bearer ${this.config.supabaseServiceRoleKey}`,
      apikey: this.config.supabaseServiceRoleKey,
      "Content-Type": contentType,
    };
  }
}

async function readJson(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function readString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length ? trimmed : null;
}

function readNumberArray(value: unknown): number[] | null {
  if (!Array.isArray(value)) return null;
  const numbers = value.filter((item): item is number => typeof item === "number" && Number.isFinite(item));
  return numbers.length === value.length ? numbers : null;
}

function readObject(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}
