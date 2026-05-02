# Supabase Seed Notes

The verified local prototype seeds fixture data through the Python ingestion path instead of direct SQL because each beat also needs audio copied into storage and local feature extraction performed first.

Recommended production seeding flow:

1. materialize the fixture audio
2. upload audio into the `beat-audio` bucket
3. insert into `public.beats`
4. insert audio + metadata embeddings into `public.beat_embeddings`
5. insert perceptual signatures into `public.beat_signatures`

The local fixture source of truth is:

- `backend/tests/fixtures/fixture_catalog.json`
