# Release Checklist

Run top to bottom for every release.

## 1. Code readiness

- [ ] CI green on the release commit (backend, iOS build, container, secret scan).
- [ ] `python3 scripts/dev/lint.py`, full unittest discovery, and `python3 scripts/eval/run_eval.py` pass locally.
- [ ] Working tree clean; release commit tagged (`git tag v<version>`).
- [ ] `docs/production-roadmap.md` and `docs/final-production-audit.md` reflect reality.

## 2. Backend

- [ ] Staging deployed on Render from `render.yaml` (Starter plan + 1 GB disk, ≈$7.25/month — see "Render staging" in `docs/deployment.md`); staging URL recorded there.
- [ ] Staging `GET /health` returns 200 with `storage_mode: local`; text and audio smoke tests pass; state survives a service restart.
- [ ] Backend deployed (owner-approved host, `docs/deployment.md`) and `GET /health` shows expected `storage_mode` / `supabase_configured`.
- [ ] Supabase migrations applied (`supabase db push`) when using mirror/primary mode.
- [ ] Rate limits and upload caps verified with a manual oversized/rapid-fire request.
- [ ] Real beat catalog ingested (fixture data is for CI only).
- [ ] YouTube backfill run with the production API key; quota consumption reviewed.

## 3. iOS build

- [ ] Bump `CURRENT_PROJECT_VERSION` (and `MARKETING_VERSION` when user-facing).
- [ ] Production backend URL verified in Settings on a device build.
- [ ] StoreKit products live in App Store Connect and IDs match the code.
- [ ] Privacy manifest present; archive uploaded; TestFlight checklist (`docs/testflight-checklist.md`) complete.

## 4. Compliance

- [ ] Privacy policy and terms published at their URLs, satisfying `docs/privacy-and-compliance.md`.
- [ ] App privacy questionnaire matches actual data flows.

## 5. Submission

- [ ] Internal TestFlight round complete with no blocking feedback.
- [ ] App Store review notes explain the demo flow (a sample search query and expectations).
- [ ] Phased release enabled for the first version.

## 6. Post-release

- [ ] Monitor backend logs and rate-limit hits for the first days.
- [ ] Monitor TestFlight/App Store crash reports.
- [ ] Schedule the incremental YouTube sync job (cron on the host).
