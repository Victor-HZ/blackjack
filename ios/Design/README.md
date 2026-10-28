# iOS design review

Open `preview.html` in a browser. It is self-contained, works offline, and requires no build step or external assets.

**This is an interactive design prototype, not the native iOS app, an iOS Simulator recording, or App Store screenshots.** It recreates the visual direction of the current SwiftUI source. Native rendering, device behavior, and accessibility still need to be checked with Xcode on real iPhones or the iOS Simulator.

The four phone frames show:

1. A focused training dashboard and next-session recommendation.
2. A working miniature card-value drill with correct/incorrect feedback and a result screen.
3. Progress with explicitly illustrative sample data.
4. The one-time Pro offer. The displayed $19.99 is an illustrative local StoreKit test price; there is no payment in this artifact. The native app obtains its price from StoreKit.

Try each phone's tabs, the counting answers, pause/resume, and the light/dark toggle. Preview notices appear outside the phone frames. The table and purchase views are visual review surfaces; the actual game engine and transaction handling live in the native app.

The native implementation remains the source of truth:

- `../BlackjackStudio/Features/TrainScreen.swift`
- `../BlackjackStudio/Training/DrillSessionView.swift`
- `../BlackjackStudio/Features/ProgressScreen.swift`
- `../BlackjackStudio/Commerce/PaywallView.swift`

Do not submit this artifact or captures of it as App Store screenshots. Capture the compiled app on supported Apple devices for release materials.
