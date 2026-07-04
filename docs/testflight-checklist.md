# TestFlight Checklist

Current verified values (from `BeatFinder.xcodeproj`):

- Bundle ID: `com.alix3bs.BeatFinder`
- Marketing version: `1.0`; build number: `1` (increment the build number for every TestFlight upload)
- Deployment target: iOS 18.0
- Microphone purpose string (already set): "BeatFinder records short snippets so we can match your beat."

## Owner-account steps (cannot be automated from this repository)

1. Apple Developer Program membership active.
2. In Xcode, sign in with the team and enable automatic signing for the `BeatFinder` target (creates the App ID + provisioning profile). No certificates or profiles are stored in this repository — do not commit them.
3. In App Store Connect, create the app record for `com.alix3bs.BeatFinder`.
4. Archive (Product → Archive) with a Release configuration and upload via Xcode Organizer.
5. Complete export compliance (the app uses only standard HTTPS — "standard encryption, exempt" answer applies).

## Before the first build upload

- [ ] Point Settings → Backend to a deployed HTTPS backend (see `docs/deployment.md`); the local/LAN presets are development-only.
- [ ] Confirm upload search works end-to-end against that backend on a physical device.
- [ ] Confirm microphone record-to-search prompts with the purpose string.
- [ ] Confirm Safe persists across app relaunches.
- [ ] Set the StoreKit configuration OFF for archive builds (scheme Run option only affects local runs, but verify).

## Internal testing setup

1. App Store Connect → TestFlight → Internal Testing: create a group, add internal testers (up to 100, no review required).
2. Assign the uploaded build to the group.
3. Testers install via the TestFlight app.
4. Collect feedback/crashes in App Store Connect → TestFlight → Crashes & Feedback.

## Known TestFlight-stage limitations

- Subscriptions use placeholder product IDs until App Store Connect products exist (`docs/subscriptions.md`); paywall purchase attempts will show "no plans" until then — expected.
- Producer discovery serves indexed metadata; run the YouTube backfill job to populate real channels first (`docs/producer-discovery.md`).
