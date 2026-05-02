# Known Issues

- The verified local build uses deterministic local embeddings instead of live Hugging Face embeddings because outbound model access was unavailable here.
- The Gemma layer supports a remote HTTP provider contract, but the validated local path remains the deterministic fallback.
- Supabase primary mode is implemented, including a live integration test, but it was not executed in this environment because no live project credentials were available.
- The local API smoke test is still skipped in this sandbox because local TCP socket binding is blocked.
- The fixture dataset uses synthesized WAV audio. It is useful for repeatable regression testing, but it is not a substitute for production evaluation on licensed real beat audio.
- The legacy `worker/` directory targets an older schema and is documented as non-authoritative for this v1 until it is rewritten.
