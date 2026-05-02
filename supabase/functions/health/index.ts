import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(() => {
  return new Response(
    JSON.stringify({
      status: "ok",
      service: "beatfinder-hybrid-retrieval",
      mode: "thin-edge-health",
    }),
    {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
});
