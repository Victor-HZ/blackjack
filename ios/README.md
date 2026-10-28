# Blackjack Studio for iOS

A native SwiftUI learning app for iPhone and iPad, with an original design, private local progress, and a one-time StoreKit Pro unlock. Minimum deployment target: iOS 17.

This is a **native project**, not a WebView wrapper. The existing React web app remains at the repository root.

## Open and run on a Mac

1. Install a current Xcode version that satisfies Apple's current submission requirements. The cloud workspace is Linux and cannot supply the iOS SDK.
2. Open `BlackjackStudio.xcodeproj`. Select the **BlackjackStudio** scheme and an iPhone simulator.
3. Run. The Debug scheme uses the included local StoreKit configuration; its test purchases do not charge money.
4. Select **Product → Test** to run the native flow and local StoreKit tests. Inspect iPhone and iPad layouts, large text, VoiceOver, dark mode, and background/restore behavior.

No backend, API key, CocoaPods install, or third-party Swift package download is needed. Three local packages are linked into the app.

## What's implemented

- A two-step introduction with experience and daily practice preferences.
- Eight short lessons, 24 checks, and six finite drills.
- Card values, pair cancellation, running counts, full-deck checkpoints, deck estimation, and true counts.
- Paused timing, negative-answer entry, automatic completion saving, mistake review, and adaptive recommendations.
- A simulated blackjack table with strategy feedback, all standard actions, configurable rules, and count recall.
- Fixed 10-, 25-, or 50-round simulations with Guided/Test modes, optional count recall, saved/resumable sessions, and first-attempt skill scores.
- Targeted feedback: replay missed decisions, review the exact session rules, practice the running count, and repeat a session. See [the simulation flow](Documentation/SIMULATION.md).
- A free rule-aware strategy reference with hard, soft, and pair charts plus hypothetical-hand lookup.
- Local progress trends, session history, export, reminders chosen by the user, and deletion.
- System light/dark appearance, true-black dark backgrounds, shared contrast-aware colors, grouped layouts, large-text alternatives, and optional haptics.
- StoreKit 2 transaction verification for purchases, restoration, and refunds, with a dismissible, localized-price paywall.
- Original vector/raster icon assets, privacy manifest, listing copy, policy-page drafts, and release configuration validation.

Free includes the first two lessons, the boundaries lesson, card-value and running-count drills, the standard practice table, and fixed-round simulations. Pro unlocks the remaining lessons/drills and advanced table rules/count tools. There are no subscriptions, ads, real-money wagers, purchasable chips, or casino connections.

## Validation and honest release status

**Executed in this Linux environment:** 88 XCTest cases across BlackjackCore (40), TrainingCore (15), and StudioCore (33). Native source parsing and the Xcode project check pass. The offline design preview has seven passing browser checks for live appearance changes, contrast, drill interactions, offline use, and reduced motion; all 22 repository browser checks pass, including five simulation scenarios.

**Not executed here:** Apple SDK type checking, an iOS simulator/device build, the eleven native UI/StoreKit tests, Sandbox/TestFlight purchases, signing, or App Store submission. The macOS GitHub workflow is committed; its remote run status is unavailable through the current environment’s API proxy. Passing Linux tests does not establish native UI or App Review readiness.

The code uses ordinary native iOS APIs, but Apple SDK/compiler issues can only be ruled out by the first Xcode build. Current Apple policy pages and statutory sources were blocked by this environment's network policy; see `Documentation/RESEARCH.md` for verified evidence and remaining checks.

## Run portable native tests

```sh
./scripts/test-core.sh
```

On the prepared cloud machine, the verified Swift 6.2 compiler is retained at `/workspace/.toolchains/swift-6.2/usr/bin/swift`. To reproduce it on Linux x86_64, use `scripts/install-swift-linux.sh`; it verifies the official signature and pinned checksum before extraction. It does not install an iOS SDK.

After adding/removing native source files:

```sh
python3 scripts/generate-xcode-project.py
```

The generated Xcode project is checked in; no XcodeGen installation is needed.

## Review the design without a Mac

Open `Design/preview.html` in a browser or serve it as a local static file. It is an interactive **design prototype**, with clearly labeled sample progress and sample pricing. It is not the iOS executable and must not be used as proof of native rendering or submitted as App Store screenshots.

The native SwiftUI implementation is the source of truth. The preview defaults to system appearance, with Light and Dark overrides for review. `AppFlowTests.testCaptureRepresentativeNativeScreens` captures actual native screens in both appearances when run in Xcode.

## Publish

Follow [the release guide](Documentation/RELEASE.md) and [monetization setup](Documentation/MONETIZATION.md). Before publishing, you need:

- Access to macOS/Xcode (a personal or cloud Mac) and Apple Developer Program membership.
- Your unique bundle ID, Apple team, App Store Connect app, and non-consumable Pro product.
- A chosen price, applicable paid-app agreements, tax/banking details, and public support/privacy/terms URLs.
- A successful native build, simulator/device checks, Sandbox/TestFlight purchase tests, truthful age-rating answers, and current policy review.

The signed release gate deliberately rejects placeholder identities or missing public URLs:

```sh
./scripts/validate-release.sh
```

Do not disable that gate to make a release appear complete. Configuration files contain identifiers only; do not commit signing keys, certificates, passwords, or private App Store Connect keys.

`Storefront/` contains draft listing text and owner-neutral privacy/terms pages. Host and review those pages under your own domain, provide a functioning support/contact page, and verify that all published statements match the final app.
