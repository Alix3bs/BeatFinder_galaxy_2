# Test Plan

## Test Matrix

### Unit Tests

- `backend/api/request_parsers.test.ts`
  - multipart parsing
  - file/base64 extraction
  - JSON-ish field coercion
- `backend/tests/test_metadata_parser.py`
  - artist extraction
  - producer combo extraction
  - hashtag normalization
  - explicit producer alias handling
- `backend/tests/test_query_normalization.py`
  - region combo handling
  - plain combo phrase preservation
- `backend/tests/test_signature_and_scoring.py`
  - deterministic signature generation
  - rerank fusion behavior
- `backend/tests/test_embedding_contract.py`
  - 384-dim audio embedding contract
  - 384-dim metadata embedding contract
  - vector literal round-trip
- `backend/tests/test_gemma_adapter.py`
  - local fallback behavior
  - remote-provider fallback behavior

### Integration Tests

- `backend/tests/test_integration_retrieval.py`
  - ingest beat -> embeddings + signature stored
  - exact audio query -> source beat ranks first
  - short clip query -> source beat stays near the top
  - metadata query -> matching beat family appears in results
  - hybrid query -> exact beat ranks better than text-only
  - base64 ingest and base64 search paths
- `backend/tests/test_storage_adapter_parity.py`
  - scan-all retrieval path and candidate-adapter path return the same top results
- `backend/tests/test_supabase_primary_integration.py`
  - env-gated live Supabase-primary ingest/search/feedback flow

### API Smoke

- `backend/tests/test_api_smoke.py`
  - `/health`
  - `/ingest/beat`
  - `/search/text`
  - multipart `/search/hybrid`

The API smoke test is skipped automatically when socket binding is blocked by the environment.

## Fixture Dataset

Fixtures are synthesized from `backend/tests/fixtures/fixture_catalog.json`.

Cases included:

1. `SZA x Summer Walker Type Beat - Late Nights`
2. `SZA x Summer Walker Type Beat - Afterglow`
3. `New York Drill Type Beat - Midnight Rush`
4. `Milwaukee x Detroit Type Beat - Cold Motion`
5. `SZA Type Beat - Silk Room`
6. `Detroit Drill Type Beat - Tunnel Vision`
7. `Summer Walker Type Beat - City Lights`

These cover:

- artist combos
- producer combos
- producer aliases
- region phrases
- drill vs rnb families
- hashtag normalization
- hybrid ranking behavior

## Expected Outcomes

- exact same audio returns the same beat at rank 1
- short clip still returns the original beat in top results
- text query returns a correct family even when multiple beats share the same artist phrase
- hybrid query upgrades the exact audio-backed beat above neighboring text matches
- every result includes a score breakdown
- multipart uploads map correctly into the existing ingest/search payload contract
- store-backed candidate generation does not change the top-ranked results versus the scan-based fallback

## Known Weak Spots

- the verified local environment uses synthetic fixtures, not commercial beat marketplace audio
- Hugging Face and Gemma remote access were not available during local verification
- live Supabase-primary integration coverage is implemented but skipped without credentials
- live socket-based API testing is blocked in this sandbox
