# Validation record

Validated in the Linux cloud workspace. UI refinement checks repeated on 2026-10-28 (UTC).

## Executed

| Check | Result |
| --- | --- |
| Official Swift 6.2 compiler download | Detached GPG signature and pinned SHA-256 verified before extraction |
| BlackjackCore XCTest | 40 passed, including 600-round deterministic ledger/rule/shuffle exercise |
| TrainingCore XCTest | 15 passed, including Hi-Lo balance, true-count rounding, deterministic prompts, completed-summary validation, and recommendations |
| StudioCore XCTest | 10 passed, including persistence recovery, ordered background writes/reset, weighted accuracy, time-zone-aware activity, and safe rule changes |
| Native Swift syntax | All 15 app source files and 2 UI-test source files parse with Swift 6.2 |
| Strategy chart row construction | All 34 hard/soft/pair rows checked against native types and representative advice |
| Xcode project | Deterministic generator repeatable; PBX/property-list/XML structure and target/resource references valid |
| App assets | All iPhone/iPad/App Store icon entries generated; 1024px marketing icon opaque |
| Local StoreKit file | JSON parsed; product schema checked against Apple's official sample; bundled only in UI tests |
| Release validator | Positive isolated configuration fixture passes; default publisher placeholders correctly fail |
| Design prototype | Seven Playwright checks pass: live system switching at 1440/390px without losing drill state, appearance overrides, primary-action contrast in both modes, complete scored drill/navigation, offline interaction, and reduced motion; no 390px overflow |

The existing web app was rechecked with 50 passing Vitest tests and a production build. All 17 browser checks pass (10 web app + 7 design prototype). Its application source was not changed for this UI refinement. The prototype’s primary-action text contrast is at least 15.25:1; this browser measurement does not substitute for native accessibility validation. Both overview PNGs were refreshed and visually inspected.

## Not executed

- Apple SDK type checking or native app compilation.
- iOS Simulator/device rendering, performance, VoiceOver, Dynamic Type, or Reduce Motion validation.
- Nine native XCUITest/StoreKitTest scenarios. They are implemented for the first Xcode run, not reported as passed. The capture scenario now requests both Light and Dark appearance; updated flow assertions match the simplified headings.
- Sandbox/TestFlight purchases, reinstall/other-device restoration, pending purchases, refunds, or offline entitlement behavior against Apple's live sandbox.
- macOS GitHub Actions results. The workflow is committed, but the current API proxy does not expose its remote run status.
- Signing, archive upload, publication, App Review, or fresh-task cloud-environment restoration.
- Current Apple policy/statute/competitor page review; those domains were blocked during research. Official Apple GitHub StoreKit examples were accessible and examined.

## Remaining publisher work

The release validator currently fails by design for the example bundle ID/product ID, missing Apple team, and missing hosted privacy/terms/support URLs. Those are genuine external prerequisites; no identifiers, accounts, legal entity, or public URLs were fabricated.

Passing core tests, source parsing, and project-structure checks does not establish that the first native build or StoreKit UI test run will pass. Resolve any diagnostics on macOS before shipping. Do not use the HTML design review images as native screenshots.
