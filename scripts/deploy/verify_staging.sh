#!/usr/bin/env bash
# BeatFinder staging verification.
#
# Usage:
#   scripts/deploy/verify_staging.sh https://<service>.onrender.com          # full check (ingests 1 probe beat)
#   scripts/deploy/verify_staging.sh https://<service>.onrender.com --check  # re-check after a restart
#
# Requires: bash, curl, python3 (stdlib only). Sends no secrets; reads none.
#
# Full mode ingests one tiny synthesized beat ("Staging Persistence Probe")
# so beats_indexed becomes >= 1; --check mode verifies it survived a service
# restart, proving the /data disk is persistent.
set -euo pipefail

BASE="${1:?Usage: verify_staging.sh https://<service>.onrender.com [--check]}"
MODE="${2:-full}"
BASE="${BASE%/}"

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; exit 1; }

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# 1. Health returns 200 with expected fields and no secret-like content.
health_code="$(curl -sS -o "$workdir/health.json" -w '%{http_code}' "$BASE/health")"
[ "$health_code" = "200" ] || fail "GET /health returned HTTP $health_code"
pass "GET /health returned HTTP 200"

python3 - "$workdir/health.json" <<'PY'
import json, re, sys
raw = open(sys.argv[1], encoding="utf-8").read()
payload = json.loads(raw)
assert payload.get("status") == "ok", payload
assert payload.get("storage_mode") == "local", payload
assert isinstance(payload.get("supabase_configured"), bool), payload
allowed = {"status", "state_dir", "beats_indexed", "storage_mode", "supabase_configured", "query_audio_retention"}
unexpected = set(payload) - allowed
assert not unexpected, f"unexpected health fields: {unexpected}"
secretish = re.compile(r"(sb_secret_|service_role|SUPABASE_SERVICE|eyJ[A-Za-z0-9_-]{20,}|api[_-]?key)", re.I)
assert not secretish.search(raw), "health response contains secret-like content"
print(f"      storage_mode={payload['storage_mode']} beats_indexed={payload['beats_indexed']}")
PY
pass "health response has expected fields only, no secret-like content"

beats_before="$(python3 -c "import json;print(json.load(open('$workdir/health.json'))['beats_indexed'])")"

if [ "$MODE" = "--check" ]; then
    [ "$beats_before" -ge 1 ] || fail "beats_indexed is $beats_before after restart; persistent disk did not retain state"
    pass "persistent state survived restart (beats_indexed=$beats_before)"
    echo "ALL CHECKS PASSED (post-restart)"
    exit 0
fi

# 2. Synthesize a tiny WAV (2 s, 16 kHz mono sine) with the stdlib only.
python3 - "$workdir/probe.wav" <<'PY'
import math, struct, sys, wave
path = sys.argv[1]
rate, seconds, freq = 16000, 2.0, 220.0
frames = b"".join(
    struct.pack("<h", int(12000 * math.sin(2 * math.pi * freq * i / rate)))
    for i in range(int(rate * seconds))
)
with wave.open(path, "wb") as handle:
    handle.setnchannels(1)
    handle.setsampwidth(2)
    handle.setframerate(rate)
    handle.writeframes(frames)
PY

# 3. Ingest one probe beat so the index is non-empty and persistence is testable.
python3 - "$workdir/probe.wav" > "$workdir/ingest.json" <<'PY'
import base64, json, sys
print(json.dumps({
    "title": "Staging Persistence Probe",
    "producer_name": "beatfinder staging",
    "genre_tags": ["test"],
    "region_tags": [],
    "source_platform": "staging-probe",
    "audio_base64": base64.b64encode(open(sys.argv[1], "rb").read()).decode("ascii"),
    "audio_file_name": "staging-probe.wav",
    "audio_mime_type": "audio/wav",
}))
PY
ingest_code="$(curl -sS -o "$workdir/ingest_resp.json" -w '%{http_code}' \
    -X POST "$BASE/ingest/beat" -H 'Content-Type: application/json' \
    --data-binary @"$workdir/ingest.json")"
[ "$ingest_code" = "200" ] || { cat "$workdir/ingest_resp.json"; fail "ingest probe returned HTTP $ingest_code"; }
pass "probe beat ingested"

# 4. Text search smoke test.
text_code="$(curl -sS -o "$workdir/text.json" -w '%{http_code}' \
    -X POST "$BASE/search/text" -H 'Content-Type: application/json' \
    -d '{"query":"staging persistence probe","top_n":3}')"
[ "$text_code" = "200" ] || fail "text search returned HTTP $text_code"
python3 - "$workdir/text.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert "results" in payload and "discovery" in payload and "confidence" in payload, payload.keys()
assert payload["results"], "text search returned no results for the probe beat"
print(f"      top result: {payload['results'][0]['beat']['raw_title']}")
PY
pass "text search returns the probe beat with explainable fields"

# 5. Multipart audio upload smoke test (same file should match itself).
audio_code="$(curl -sS -o "$workdir/audio.json" -w '%{http_code}' \
    -X POST "$BASE/search/audio" \
    -F "audio=@$workdir/probe.wav;type=audio/wav" -F "top_n=3")"
[ "$audio_code" = "200" ] || fail "audio upload search returned HTTP $audio_code"
python3 - "$workdir/audio.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload.get("query_type") == "audio", payload.get("query_type")
assert payload.get("results"), "audio search returned no results"
top = payload["results"][0]["beat"]["raw_title"]
assert top == "Staging Persistence Probe", f"expected probe beat first, got {top!r}"
print(f"      top result: {top} (signature {payload['results'][0].get('signature_score')})")
PY
pass "multipart audio upload matches the probe beat"

echo
echo "ALL CHECKS PASSED"
echo "Now restart the service (Render dashboard -> Manual Deploy -> Restart),"
echo "wait for it to become live, then run:"
echo "  scripts/deploy/verify_staging.sh $BASE --check"
