# iOS design preview

Open [preview.html](preview.html) directly in a browser. It is self-contained, works offline, and requires no build or external assets.

This is an **interactive design prototype**, not a compiled iOS app, Simulator capture, or App Store screenshot. The intended SwiftUI implementation lives in `ios/BlackjackStudio`. Fixed-round simulation is implemented in the native app and React web app; this lightweight HTML prototype does not include that newer flow. See [the native simulation documentation](../Documentation/SIMULATION.md).

The four initial frames show:

- Practice: a daily goal, one session, and a grouped skill library.
- Card values: a working 15-card Hi-Lo drill, including pause, feedback, results, and restart.
- Progress: illustrative session and accuracy data.
- Pro: a one-time unlock with an illustrative $19.99 price. No purchase occurs here.

Appearance defaults to **System** and follows the operating system live, including true-black dark backgrounds. **Light** and **Dark** provide temporary preview overrides; choose **System** to resume automatic switching. Changing appearance preserves the current question, score, and screen. Card faces stay cream in both appearances. Reduced-motion preferences disable transitions.

Use the tabs to review lessons and the practice table. Only the card-value drill is a working training interaction in this HTML; the table, settings, other drills, and purchase controls show preview information. Progress and lesson completion are sample data, not persisted practice records.

The preview follows the shared native palette and restrained grouped layouts in:

- [TrainScreen.swift](../BlackjackStudio/Features/TrainScreen.swift)
- [DrillSessionView.swift](../BlackjackStudio/Training/DrillSessionView.swift)
- [ProgressScreen.swift](../BlackjackStudio/Features/ProgressScreen.swift)
- [PaywallView.swift](../BlackjackStudio/Commerce/PaywallView.swift)

Browser regressions in `e2e/ios-design.spec.ts` cover automatic and manual appearance, live state preservation, contrast, narrow layouts, reduced motion, and drill/navigation behavior. They do not validate native SwiftUI rendering; that requires Xcode and an Apple SDK.
