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

    const sourceValue = snippetUrl || sourceUrl;
    const fingerprintHash = await sha256Hex(sourceValue);

    return json({
      fingerprint_hash: fingerprintHash,
      source: snippetUrl ? "snippet_url" : "source_url",
    });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
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
