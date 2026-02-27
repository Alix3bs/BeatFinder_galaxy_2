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
    const sourceUrl = String(body?.source_url ?? "").trim();

    if (!snippetUrl && !sourceUrl) {
      return json({ error: "Provide snippet_url or source_url" }, 400);
    }

    // MVP placeholder:
    // Add real fingerprint extraction + nearest-neighbor match in Phase 2.
    return json({
      source: "mock_audio_match",
      likely_custom: true,
      explanation: "No high-confidence fingerprint match in indexed sources.",
      matches: [
        {
          platform: "YouTube",
          title: "Closest spectral match (mock)",
          url: "https://www.youtube.com/results?search_query=type+beat",
          similarity: 0.58,
          note: "Closest low-confidence candidate.",
        },
      ],
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

