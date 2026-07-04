# BeatFinder Subscriptions

## Architecture

Billing and entitlements are deliberately separated:

- `BeatFinder/SubscriptionManager.swift` — StoreKit 2 only: loads products, purchases, restores (`AppStore.sync()`), observes `Transaction.updates`, and derives `isPro` from `Transaction.currentEntitlements`. Expired and revoked transactions never appear in `currentEntitlements`, so `isPro` drops automatically when a subscription lapses or is refunded; `Transaction.updates` triggers a re-check while the app is running.
- `BeatFinder/EntitlementModel.swift` — pure policy: what each tier may do. UI and view models consume `BeatFinderEntitlements.current(isPro:)` and never touch StoreKit types.
- `SearchQuotaTracker` — local, anonymous daily search counter with midnight rollover. No server, no personal data.

## Tier model

| Control | Free | Pro |
| --- | --- | --- |
| Daily searches | 10 | unlimited |
| Upload analysis length | 30 s | 90 s (preprocessor cap) |
| Saved results in Safe | 25 | unlimited |
| Producer discovery enrichment | included | included |

These are policy defaults, adjustable in one place (`BeatFinderEntitlements.free/.pro`). Enforcement call sites: `SearchQuotaTracker.canSearch(with:)` before dispatching a search, `BeatFinderEntitlements.canSave(currentSavedCount:)` before Safe writes, and `maxUploadSeconds` as the preprocessor cap.

## Product identifiers

`com.beatfinder.pro.monthly` and `com.beatfinder.pro.yearly` are **placeholders shared by the code and the local StoreKit configuration**. They are not live App Store products; nothing in the app pretends they are. Keep code, `BeatFinder/BeatFinder.storekit`, and App Store Connect in sync when the real products are created.

## Local testing with the StoreKit configuration

`BeatFinder/BeatFinder.storekit` defines both subscriptions in one group ("BeatFinder Pro"). To use it:

1. Open the scheme editor (Product → Scheme → Edit Scheme… → Run → Options).
2. Set **StoreKit Configuration** to `BeatFinder.storekit`.
3. Run in the simulator; purchases, restores, expiration, and refunds can be exercised through Xcode's transaction manager without an App Store Connect account.

## App Store Connect steps still required (owner account)

1. Create the app record with the final bundle identifier.
2. Create a subscription group "BeatFinder Pro" and both products with the identifiers above (or update the identifiers in `SubscriptionManager.swift` and `BeatFinder.storekit` to match what is created).
3. Fill in localized display names, descriptions, prices, and review screenshots.
4. Accept the Paid Applications agreement and complete banking/tax forms.
5. Add subscription terms links (privacy policy URL and terms of use URL) to the app metadata — required for auto-renewable subscriptions.
6. Submit the subscriptions with the first app review build.

## Website / external subscription project

This repository contains only the iOS app and the retrieval backend. No separate BeatFinder website or web-subscription project exists here (the `worker/` directory is legacy retrieval scaffolding, not a storefront). If a web project exists elsewhere, it must not be mixed into this repository without explicit confirmation of its location.
