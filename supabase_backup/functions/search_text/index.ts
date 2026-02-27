// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Candidate = {
  platform: "YouTube" | "SoundCloud" | "Spotify" | "Apple Music" | "Web";
  url: string;
  title: string;
  similarity: number;
  bpm?: number;
  key?: string;
  note?: string;
};

type SearchContext = {
  cityStyles: string[];
  artistHints: string[];
  producerTagHints: string[];
  moodHints: string[];
  expandedQueries: string[];
  hasCustomHint: boolean;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

const CITY_STYLE_HINTS: Record<string, string[]> = {
  philly: ["philly", "philadelphia", "meek", "uzi", "philly drill"],
  atlanta: ["atl", "atlanta", "future", "young thug", "lil baby"],
  detroit: ["detroit", "rio da yung og", "babytron", "veeze"],
  nyc: ["new york", "ny", "bronx", "brooklyn", "drill ny"],
  chicago: ["chicago", "chiraq", "chief keef", "g herbo"],
};

const ARTIST_HINTS: Record<string, string[]> = {
  drake: ["drake", "ovo"],
  future: ["future", "pluto"],
  travis: ["travis scott", "travis", "cactus jack"],
  lilbaby: ["lil baby", "4pf"],
  meek: ["meek mill", "meek"],
  uzi: ["lil uzi", "uzi"],
  centralcee: ["central cee", "cench"],
};

const MOOD_HINTS = [
  "dark",
  "melodic",
  "aggressive",
  "ambient",
  "soulful",
  "gritty",
  "club",
  "emotional",
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const query = String(body?.query ?? "").trim();
    const forceWeb = Boolean(body?.force_web);
    const limit = Math.min(Math.max(Number(body?.limit ?? 10), 1), 25);

    if (!query) {
      return json({ error: "Missing query" }, 400);
    }

    // MVP stub:
    // Replace this with real multi-source search calls and ranking.
    // This still returns normalized candidates for iOS integration today.
    const context = buildSearchContext(query);
    const candidates = buildMockCandidates(query, forceWeb, context).slice(0, limit);

    return json({
      query,
      source: "mock_edge_function",
      force_web: forceWeb,
      context: {
        city_styles: context.cityStyles,
        artist_hints: context.artistHints,
        producer_tag_hints: context.producerTagHints,
        mood_hints: context.moodHints,
        expanded_queries: context.expandedQueries,
      },
      matches: candidates,
    });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

function buildMockCandidates(query: string, forceWeb: boolean, context: SearchContext): Candidate[] {
  const lowered = context.hasCustomHint;
  const drop = forceWeb ? 0 : 0.04;
  const contextBoost = computeContextBoost(context);
  const stylePrefix = context.cityStyles.length ? `${titleCase(context.cityStyles[0])} ` : "";
  const artistPrefix = context.artistHints.length ? `${titleCase(context.artistHints[0])} ` : "";
  const note = buildContextNote(context);

  if (lowered) {
    return [
      {
        platform: "YouTube",
        url: `https://www.youtube.com/results?search_query=${encodeURIComponent(query)}`,
        title: `${artistPrefix}${stylePrefix}${query} instrumental (fan upload)`,
        similarity: 0.56 - drop + contextBoost * 0.02,
        bpm: chooseBpmByCity(context.cityStyles[0] ?? ""),
        key: chooseKeyByMood(context.moodHints),
        note,
      },
      {
        platform: "SoundCloud",
        url: `https://soundcloud.com/search?q=${encodeURIComponent(query)}`,
        title: `${query} ${stylePrefix}style beat`,
        similarity: 0.49 - drop + contextBoost * 0.015,
        bpm: chooseBpmByCity(context.cityStyles[0] ?? ""),
        key: chooseKeyByMood(context.moodHints),
        note,
      },
    ];
  }

  return [
    {
      platform: "YouTube",
      url: `https://www.youtube.com/results?search_query=${encodeURIComponent(query)}`,
      title: `${artistPrefix}${stylePrefix}${query} | Official Type Beat`,
      similarity: 0.93 - drop + contextBoost * 0.04,
      bpm: chooseBpmByCity(context.cityStyles[0] ?? ""),
      key: chooseKeyByMood(context.moodHints),
      note,
    },
    {
      platform: "SoundCloud",
      url: `https://soundcloud.com/search?q=${encodeURIComponent(query)}`,
      title: `${query} ${stylePrefix}(alt upload)`,
      similarity: 0.85 - drop + contextBoost * 0.03,
      bpm: chooseBpmByCity(context.cityStyles[0] ?? ""),
      key: chooseKeyByMood(context.moodHints),
      note,
    },
    {
      platform: "Spotify",
      url: `https://open.spotify.com/search/${encodeURIComponent(query)}`,
      title: `${query} preview`,
      similarity: 0.73 - drop + contextBoost * 0.01,
      note: context.producerTagHints.length
        ? "Metadata boosted by producer-tag/style cues."
        : undefined,
    },
  ];
}

function buildSearchContext(query: string): SearchContext {
  const lower = query.toLowerCase();

  const cityStyles = Object.entries(CITY_STYLE_HINTS)
    .filter(([, cues]) => cues.some((cue) => lower.includes(cue)))
    .map(([city]) => city);

  const artistHints = Object.entries(ARTIST_HINTS)
    .filter(([, cues]) => cues.some((cue) => lower.includes(cue)))
    .map(([artist]) => artist);

  const moodHints = MOOD_HINTS.filter((mood) => lower.includes(mood));

  const producerTagHints: string[] = [];
  if (lower.includes("producer tag") || lower.includes("prod by") || lower.includes("tag")) {
    producerTagHints.push("producer tag phrasing");
  }
  if (lower.includes("voice tag") || lower.includes("vox")) {
    producerTagHints.push("voice tag cue");
  }
  if (lower.includes("808 mafia") || lower.includes("southside")) {
    producerTagHints.push("producer collective style");
  }

  const hasCustomHint = lower.includes("custom") || lower.includes("unreleased");

  const expandedQueries = new Set<string>([query]);
  cityStyles.forEach((city) => expandedQueries.add(`${titleCase(city)} type beat`));
  artistHints.forEach((artist) => expandedQueries.add(`${titleCase(artist)} type beat`));
  if (cityStyles.length && artistHints.length) {
    expandedQueries.add(`${titleCase(artistHints[0])} x ${titleCase(cityStyles[0])} type beat`);
  }
  if (producerTagHints.length) {
    expandedQueries.add(`${query} producer tag`);
  }

  return {
    cityStyles,
    artistHints,
    producerTagHints,
    moodHints,
    expandedQueries: Array.from(expandedQueries),
    hasCustomHint,
  };
}

function computeContextBoost(context: SearchContext): number {
  const score =
    context.cityStyles.length * 0.7 +
    context.artistHints.length * 0.7 +
    context.producerTagHints.length * 0.5 +
    context.moodHints.length * 0.3;
  return Math.min(1, score / 3);
}

function chooseBpmByCity(city: string): number {
  switch (city) {
    case "philly":
      return 145;
    case "detroit":
      return 154;
    case "atlanta":
      return 142;
    case "nyc":
      return 147;
    case "chicago":
      return 144;
    default:
      return 142;
  }
}

function chooseKeyByMood(moods: string[]): string {
  if (moods.includes("dark") || moods.includes("gritty")) return "F#m";
  if (moods.includes("soulful") || moods.includes("emotional")) return "Dm";
  if (moods.includes("aggressive")) return "Gm";
  return "Am";
}

function buildContextNote(context: SearchContext): string | undefined {
  const parts: string[] = [];
  if (context.cityStyles.length) {
    parts.push(`city style: ${context.cityStyles.map(titleCase).join(", ")}`);
  }
  if (context.artistHints.length) {
    parts.push(`artist cues: ${context.artistHints.map(titleCase).join(", ")}`);
  }
  if (context.producerTagHints.length) {
    parts.push(`producer-tag cues detected`);
  }
  if (!parts.length) return undefined;
  return `Ranked with ${parts.join(" | ")}.`;
}

function titleCase(value: string): string {
  return value
    .split(/[\s_]+/)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
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
