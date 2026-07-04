from __future__ import annotations

import re

# Conservative, word-level corrections applied to search queries before
# expansion. Only unambiguous misspellings and symbol variants belong here —
# anything that could change intent stays out.
WORD_CORRECTIONS = {
    "detriot": "detroit",
    "detroti": "detroit",
    "milwakee": "milwaukee",
    "milwaukie": "milwaukee",
    "philidelphia": "philadelphia",
    "philadephia": "philadelphia",
    "philedelphia": "philadelphia",
    "arkansaw": "arkansas",
    "huston": "houston",
    "memfis": "memphis",
    "atlana": "atlanta",
    "chicgo": "chicago",
    "r&b": "rnb",
    "randb": "rnb",
    "typebeat": "type beat",
    "typebeats": "type beat",
    "beatz": "beats",
}

# Expansion synonyms: the query keeps its original word and also gains the
# synonym as an extra phrase so overlap scoring can match either spelling.
EXPANSION_SYNONYMS = {
    "philly": "philadelphia",
    "philadelphia": "philly",
    "nyc": "new york",
    "ny": "new york",
    "atl": "atlanta",
    "mke": "milwaukee",
}

_TOKEN_RE = re.compile(r"[^\s]+")


def normalize_query_text(raw_text: str) -> str:
    """Correct unambiguous misspellings and symbol variants in a query."""

    def replace(match: re.Match[str]) -> str:
        token = match.group(0)
        corrected = WORD_CORRECTIONS.get(token.lower())
        return corrected if corrected is not None else token

    return _TOKEN_RE.sub(replace, raw_text.strip())


def expand_query_synonyms(normalized_text: str) -> list[str]:
    """Return additional query variants for known synonym spellings."""

    tokens = normalized_text.lower().split()
    variants: list[str] = []
    for index, token in enumerate(tokens):
        synonym = EXPANSION_SYNONYMS.get(token)
        if synonym is None:
            continue
        variant_tokens = [*tokens[:index], synonym, *tokens[index + 1 :]]
        variants.append(" ".join(variant_tokens))
    return variants
