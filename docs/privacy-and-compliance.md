# BeatFinder Privacy & Compliance Requirements

This document defines what the published privacy policy and terms must state,
based on what the system actually does. It is a requirements checklist, not
the legal text itself.

## Data the system touches

| Data | Where | Retention |
| --- | --- | --- |
| Typed search queries | backend query log; local search history on device | history is local-only, user-clearable; backend queries keep text + scores |
| Uploaded audio (searches) | backend, transiently | deleted after feature extraction by default; if retention is enabled, auto-expires (default 7 days) |
| Saved results ("Safe") | on device (UserDefaults) | until the user deletes them |
| Subscription state | StoreKit/Apple | managed by Apple; the app stores no receipts |
| Account identity (if auth is enabled) | Supabase auth | see account deletion below |

Not collected: location, contacts, advertising identifiers, background audio.

## Privacy policy must state

1. Uploaded audio is processed to compute matching features and deleted after processing (or the configured retention window) — it is never published or shared.
2. Search text may be stored to operate and improve matching quality.
3. Local history and Safe data stay on the device and can be cleared in-app.
4. Subscriptions are billed by Apple; BeatFinder does not receive payment details.
5. Contact channel for privacy requests.
6. If accounts ship: what the account stores and how to delete it (below).

## Terms must state

1. Users may only upload audio they have rights to query with.
2. Results are similarity findings, not licenses; obtaining rights to a beat happens with the producer/platform that sells it.
3. Missing-beat findings are possibilities with stated evidence, never a guarantee that a beat was sold or deleted.
4. Abuse limits (rate limiting) and acceptable use.

## YouTube API compliance

- Only the official YouTube Data API v3 is used, with an API key, for public metadata (channel listings, titles, descriptions, publish dates, privacy status).
- No audio or video is downloaded; no access controls are bypassed; no scraping of private or age-restricted content.
- Data retrieved is used to link users to the original public videos (deep links back to YouTube), consistent with the YouTube API Services Terms; cached metadata is refreshed by incremental sync and removable on request.
- The app must display YouTube content via official embeds/links, and the privacy policy must reference Google's privacy policy when API data is displayed.

## Account deletion requirement (when accounts ship)

Apple requires in-app account deletion for apps with account creation. The Supabase-backed flow must: delete the auth user, purge `created_by`-linked rows (queries, feedback), and confirm completion in-app. Until accounts ship, the app must remain fully usable without one.

## App Store privacy nutrition label (expected)

- Data used to track you: none.
- Data linked to you: none while accounts are off; identifiers + user content (queries) if accounts ship.
- Data not linked to you: audio processed transiently for app functionality.

## Data minimization commitments

- No third-party analytics SDKs.
- Microphone access only during explicit record-to-search, with the purpose string in Info.plist.
- File access through the system document picker only (no broad library permission).
