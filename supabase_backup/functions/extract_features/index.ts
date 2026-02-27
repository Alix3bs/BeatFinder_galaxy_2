// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const snippetUrl = String(body?.snippet_url ?? "").trim();
    if (!snippetUrl) {
      return json({ error: "Missing snippet_url" }, 400);
    }

    // MVP placeholder:
    // Replace with actual BPM/key extractor in Phase 2/3.
    return json({
      snippet_url: snippetUrl,
      bpm: 140,
      key: "Am",
      confidence: 0.42,
      source: "mock_feature_extractor",
    });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

