# Architecture

## Why Hybrid Retrieval

BeatFinder is trying to answer a harder question than plain semantic search:

- Is this the exact beat?
- If not, what are the strongest beat candidates?

That requires three separate signals:

- audio embedding similarity for broad acoustic retrieval
- perceptual signature matching for near-exact confirmation
- metadata overlap for producer tags, hashtags, artist combinations, regions, and type-beat phrases

The reranker fuses those signals into an explainable score breakdown.

## Core Components

### Ingestion

- `backend/ingest/service.py`
- `models/audio/features.py`
- `models/audio/signature.py`
- `models/metadata/parser.py`
- `models/embedding/providers.py`

Responsibilities:

- persist or stage audio input
- extract duration, sample rate, tempo estimate, chroma-ish summary, band-energy summary, envelope summary
- build a 384-dim audio embedding
- build a perceptual signature
- normalize metadata phrases
- persist beats, embeddings, and signatures through the active store adapter

### Metadata Intelligence

- `models/metadata/normalize.py`
- `models/metadata/parser.py`
- `models/metadata/gemma_adapter.py`

Capabilities:

- normalize hashtags into spaced and compact forms
- preserve combo phrases like `sza x summer walker`
- split combo parts without losing the original combo phrase
- capture producer combos, artist combos, region terms, genre terms, and type-beat phrases
- expose a Gemma-compatible interface with deterministic fallback and optional remote HTTP provider

### Storage Modes

- `backend/storage/local_store.py`
- `backend/storage/supabase_store.py`
- `backend/storage/runtime.py`

Modes:

- `local`: file-backed JSON state for offline dev and tests
- `mirror`: local-first writes plus Supabase mirror writes
- `primary`: Supabase-backed rows, storage uploads, and candidate RPCs with local scratch space for audio processing

The retrieval and ingest services only depend on the store interface, not on a specific backend.

### Retrieval

- `backend/retrieval/service.py`

Candidate sources:

- vector candidates from audio embedding search
- vector candidates from metadata embedding search
- metadata term candidates from normalized phrase search
- signature scoring across the merged candidate pool

The current local adapter can scan the full fixture set. The Supabase-primary adapter uses the SQL RPCs and HNSW-backed vector index path prepared in `supabase/migrations/`.

### Reranking

- `backend/rerank/scoring.py`

Final breakdown includes:

- `audio_embedding_score`
- `metadata_embedding_score`
- `signature_score`
- `title_phrase_overlap`
- `hashtag_overlap`
- `producer_overlap`
- `artist_overlap`
- `artist_combo_overlap`
- `producer_combo_overlap`
- `region_style_overlap`
- `bpm_closeness`

The reranker is query-aware:

- audio-only queries normalize over audio signals
- text-only queries normalize over metadata signals
- hybrid queries normalize over both

That keeps exact audio matches from being unfairly penalized for missing text hints.

## Data Flow

1. Beat ingest arrives with audio path, base64 payload, or multipart upload plus metadata.
2. Audio features and signature are computed in Python.
3. Metadata is parsed into searchable phrase arrays.
4. Audio and metadata embeddings are persisted through the active store mode.
5. Query arrives as text, audio, or hybrid.
6. Candidate pools are generated from store-backed vector and metadata search methods.
7. The reranker fuses scores and returns ranked candidates plus explanations.
8. Query + result rows are persisted for later feedback analysis.

## API Layer

- `backend/api/server.ts`
- `backend/api/request_parsers.ts`

The API layer stays intentionally thin:

- accept JSON and multipart input
- hand work to the Python CLI boundary
- return the same result contract for health, ingest, search, and feedback

Heavy DSP and ranking logic remain outside the API transport.

## Supabase Role

Supabase is the intended production system of record for:

- Postgres tables
- pgvector indexes
- Storage buckets
- auth-ready schema
- thin Edge Functions

This repo includes:

- base migration `supabase/migrations/202604200001_hybrid_retrieval_v1.sql`
- alignment migration `supabase/migrations/202604250001_alignment_storage_primary.sql`
- Edge Function scaffold `supabase/functions/health/index.ts`

The verified local run still uses the file-backed adapter because no live project credentials were available here.

## Why OpenClaw Is Not In The Hot Path

OpenClaw is a good operator/admin surface, not the retrieval engine itself.

Good uses:

- run ingest batches
- ask for uncertain results
- inspect failed jobs
- trigger re-embedding or evaluation

Bad uses:

- serving every user search request
- ranking candidates directly
- blocking app startup

## How Embeddings, Signatures, and Metadata Interact

- audio embeddings cast a wide acoustic net
- signatures provide near-exact confirmation
- metadata recovers cases where the audio is incomplete or ambiguous
- reranking is the product-quality layer that combines them honestly
