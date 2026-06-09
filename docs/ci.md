# BeatFinder CI

BeatFinder uses GitHub Actions to verify the backend and iOS project in the cloud, so local Mac storage limits do not block every build check.

## Workflow

The dedicated workflow is:

```text
.github/workflows/beatfinder-ci.yml
```

It runs on:

- pushes to `beatfinder-system-v1`
- pull requests targeting `beatfinder-system-v1`
- manual `workflow_dispatch`

The workflow uses `macos-latest` because the iOS simulator build requires Xcode. If GitHub changes the available simulator set, the workflow prints `xcrun simctl list devices available` and selects the first available iPhone simulator, preferring `iPhone 16`, then `iPhone 15`, then `iPhone 14`.

## Backend Checks

The backend job installs Python and Node, exports local runtime paths, then runs:

```bash
python3 scripts/dev/lint.py
python3 -m unittest discover -s backend/tests -p 'test_*.py' -v
python3 scripts/eval/run_eval.py
```

It also performs a local-only API smoke test:

- loads fixture beats
- loads producer YouTube seed channels
- loads mock YouTube backfill data
- starts the local API
- checks `GET /health`
- checks `POST /search/text`
- verifies `discovery_status = found_candidate`
- verifies the mock YouTube video title is `SZA x Summer Walker Type Beat - Late Nights`

This smoke test does not call live YouTube, Hugging Face, Supabase, or any external beat source.

## iOS Checks

The iOS job runs:

```bash
xcodebuild -version
xcodebuild -list -project BeatFinder.xcodeproj
plutil -lint BeatFinder.xcodeproj/project.pbxproj
swiftc -typecheck BeatFinder/BeatFinderAPIModels.swift BeatFinder/BeatFinderAPIClient.swift BeatFinder/BeatFinderBackendTestViewModel.swift
xcodebuild -project BeatFinder.xcodeproj -scheme BeatFinder -destination "platform=iOS Simulator,name=<selected iPhone>" -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
```

The simulator build disables signing so CI does not need physical-device certificates or production signing settings.

## What CI Does Not Yet Cover

GitHub Actions currently checks compile/build behavior and backend retrieval behavior. Full interactive UI testing still requires either:

- local Xcode and Simulator
- future XCUITest coverage in CI
- a dedicated device/simulator test service

CI also does not use live Supabase credentials, live Hugging Face calls, or live YouTube ingestion by default. Those integrations should stay secret-gated and explicit.

## Where To See Runs

After pushing to GitHub, open the repository Actions tab and choose `BeatFinder CI`.

```text
https://github.com/Alix3bs/BeatFinder_galaxy_2/actions
```
