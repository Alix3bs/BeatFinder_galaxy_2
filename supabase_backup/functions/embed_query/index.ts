// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

const EMBEDDING_DIMS = 1536;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const query = String(body?.query ?? "").trim();
    const forceWeb = Boolean(body?.force_web);

    if (!query) {
      return json({ error: "Missing query" }, 400);
    }

    const embedding = deterministicEmbedding(query, EMBEDDING_DIMS);

    return json({
      query,
      force_web: forceWeb,
      embedding,
      source: "deterministic_embedder",
    });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

function deterministicEmbedding(text: string, dims: number): number[] {
  // Deterministic placeholder embedding for local/dev flows.
  // Replace with provider embedding API in production.
  let state = fnv1a32(text);
  const out: number[] = [];

  for (let i = 0; i < dims; i++) {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    const normalized = (state >>> 0) / 0xffffffff; // [0, 1]
    out.push(Number((normalized * 2 - 1).toFixed(6))); // [-1, 1]
  }

  return out;
}

function fnv1a32(input: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
