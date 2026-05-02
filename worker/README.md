# BeatFinder Worker (Legacy, Not Authoritative For v1)

This directory is kept for reference only.

It targets an older Supabase queue/schema flow and is **not** the authoritative retrieval path for the current BeatFinder v1 implementation. The active v1 search path is:

- `backend/api/server.ts`
- `backend/workers/cli.py`
- `backend/ingest/service.py`
- `backend/retrieval/service.py`

## Current Status

- kept in the repo to preserve prior worker logic
- not part of the verified retrieval hot path
- not exercised by CI for the current v1
- should be rewritten against the current `beats`, `beat_embeddings`, `beat_signatures`, `queries`, `query_results`, and `feedback_events` schema before being reintroduced

## If You Need Worker-Based Ops Later

Treat this folder as a starting point for:

- background maintenance jobs
- queue-backed admin ingest
- async re-embedding

Do not route end-user `/search/*` traffic through it in its current state.
