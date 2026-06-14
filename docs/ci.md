# BeatFinder CI

BeatFinder uses GitHub Actions to verify the backend and iOS project in the cloud, so local Mac storage limits do not block every build check.

## Main Workflow

BeatFinder has one main maintained CI workflow:

```text
.github/workflows/beatfinder-ci.yml
```

The older duplicate `.github/workflows/ci.yml` was removed so the repository does not run two competing workflows with different dependency setup.

It runs on:

- pushes to `beatfinder-system-v1`
- pull requests targeting `beatfinder-system-v1`
- manual `workflow_dispatch`

The workflow uses `macos-latest` because the iOS simulator build requires Xcode. If GitHub changes the available simulator set, the workflow prints `xcrun simctl list devices available`, reads the simulator list as JSON, and selects an available iPhone simulator by UDID. It prefers `iPhone 16`, then `iPhone 15`, then `iPhone 14`, and otherwise falls back to the first available iPhone simulator.

## Backend Checks

The backend job installs Python dependencies from `requirements.txt`, installs Node for the TypeScript API checks, exports local runtime paths, forces `BEATFINDER_SUPABASE_MODE=local`, then runs:

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
xcrun simctl list devices available
xcodebuild -project BeatFinder.xcodeproj -scheme BeatFinder -destination "platform=iOS Simulator,id=<selected simulator UDID>" -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
```

The simulator build disables signing so CI does not need physical-device certificates or production signing settings. If `xcodebuild` fails, the workflow prints the exact command, selected simulator, and the last 200 build-log lines so the failure is actionable.

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

For the next run after a CI change, check the newest `BeatFinder CI` run on branch `beatfinder-system-v1`.
