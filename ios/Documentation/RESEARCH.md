# Product and release research

Research date: 27 October 2026 (America/Toronto).

## Direction

Build an original, native, offline learning app. Its value is deliberate practice, a clear progression from card values to true counts, and honest feedback about accuracy and speed. Treat generated cards as training material. Do not provide a tool for entering cards from a real casino game, camera recognition, concealed counting, wearable assistance, or real-money betting.

A compact product boundary is sufficient in the app:

> Practice only. Never use the app while gambling. Local laws and venue rules vary.

Do not claim that card counting is legal everywhere, that a casino must admit a skilled player, or that counting guarantees profit. Distinguish learning mental arithmetic from using software or devices during a game.

## Evidence actually inspected

Apple's official **Backyard Birds** sample was accessible through its GitHub repository. The reviewed revision was `1843d5655bf884b501e2889ad9862ec58978fdbe`.

- [Apple sample overview](https://github.com/apple/sample-backyard-birds/blob/1843d5655bf884b501e2889ad9862ec58978fdbe/README.md): demonstrates a native SwiftUI app, persistent data, StoreKit interfaces, and a local `.storekit` configuration selected in an Xcode scheme.
- [RestorePurchasesButton.swift](https://github.com/apple/sample-backyard-birds/blob/1843d5655bf884b501e2889ad9862ec58978fdbe/Multiplatform/Account/RestorePurchasesButton.swift): an explicit restore action invokes `AppStore.sync()` and prevents duplicate restore requests.
- [BirdBrain.swift](https://github.com/apple/sample-backyard-birds/blob/1843d5655bf884b501e2889ad9862ec58978fdbe/Multiplatform/Shop/BirdBrain.swift): verifies StoreKit transactions, ignores unverified results, observes `Transaction.updates`, handles revocation, and finishes transactions after providing their content. This sample includes consumables/subscriptions; its exact business model should not be copied into a one-time unlock.

The sample was read to inform architecture. Its code/assets were not incorporated into this product.

## Sources blocked in this environment

The following requests returned proxy `403 Forbidden`, including after approved shell network escalation. Their current contents were **not** inspected. Links below are the authoritative places to check; they are not claims of a completed legal or policy review.

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store age-rating definitions](https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/)
- [Apple app privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Nevada Revised Statutes, Chapter 465](https://www.leg.state.nv.us/NRS/NRS-465.html)
- [Blackjack Wiz — Card Counting, requested competitor](https://apps.apple.com/ca/app/blackjack-wiz-card-counting/id6788486381)

Consequently, no competitor pricing, ratings, screenshots, feature parity, current Apple approval guarantee, or jurisdiction-wide legality claim is substantiated by this research. Further competitor comparisons were not manufactured from unavailable sources.

## Learning design

1. **Card values:** 2–6 add one; 7–9 add zero; tens, faces, and aces subtract one. Use a short interaction before an explanatory paragraph.
2. **Cancellation:** pairs and small groups teach pattern recognition, including high/low cancellation, neutral cards, and same-sign pairs.
3. **Running count:** start at zero, count each exposed card once, and reset at a shuffle. A full balanced Hi-Lo deck returns to zero.
4. **Deck estimation:** practice remaining decks independently before combining it with arithmetic.
5. **True count:** divide running count by estimated decks remaining. State the app's rounding convention wherever whole-count answers are expected; different systems and index tables can use different conventions.
6. **Integrated practice:** use only a simulated table. Hide its running count by default during a challenge; reveal a concise explanation after the answer. Do not count an unrevealed dealer hole card.
7. **Review:** recommend the user's weakest measured skill; distinguish a new learner with no data from a low score. Count only completed answers and exclude paused/background time from speed scores.

Basic strategy and counting are related but different skills. Avoid implying that a high count guarantees a winning hand or that basic strategy alone removes the house edge. Teach the supported table-rule assumptions explicitly in the guide, without repeating them on every screen.

## Premium value and purchasing

Recommended initial model: useful free foundations plus **one nonconsumable Pro unlock**. A recurring subscription is difficult to justify for a static offline curriculum without recurring new value.

- Free content should demonstrate the quality of the product before a purchase prompt.
- Pro can unlock deeper drills, mixed practice, longer sessions, and more detailed progress analysis.
- Do not sell virtual wagering credits or frame the purchase as a route to income.
- Use StoreKit's localized product price and description; never display an invented fallback price as if it came from the store.
- Give pending, canceled, successful, failed, restored, and revoked purchases distinct outcomes.
- Deliver access only after verified entitlement evidence. A local preferences flag is not a purchase receipt.
- Include an accessible Restore Purchases action, a clear one-time purchase explanation, and concise support/privacy links.
- Allow existing verified owners to continue offline where StoreKit's local entitlement evidence permits it.
- Use a local StoreKit configuration for development. Test real sandbox/TestFlight purchase and restoration flows before release.

App Store Connect product identifiers, pricing territories, tax/banking agreements, support contact, legal-entity information, and product approval must be configured by the publisher. Local StoreKit success does not verify the live product configuration.

## App Review areas to re-check before submission

These are policy areas to verify against the live guidelines, not guarantees based on current fetched text:

- **Digital unlocks / purchasing:** Guidelines 3.1.1 and related provisions; app features sold in the app normally require Apple's supported purchasing flow. Check current regional rules rather than assuming one universal exception.
- **Originality and native value:** Guidelines 4.1 and 4.2. Original branding, original screenshots, and substantial native interaction reduce copycat/wrapper concerns.
- **Gambling-related content:** Section 5.3. Keep the product educational and simulated, with no real-money gaming, prizes, payouts, betting links, or casino affiliation. A teaching purpose does not automatically exempt simulated blackjack from age-rating questions.
- **Privacy:** Section 5.1 and App Store privacy declarations. If there are no ads, analytics, accounts, remote storage, or other developer-side collection, reflect that actual implementation accurately. Apple's purchase processing must not be described as developer-side tracking.
- **Age rating:** Answer the current questionnaire honestly for simulated blackjack and gambling-related educational material. Do not preselect a child-friendly age rating or market it as a children's product without reviewing those rules.
- **SDK/signing:** Use an Xcode/iOS SDK combination currently accepted by App Store Connect. An iOS deployment target is not proof that the build SDK satisfies the current submission deadline.

Nevada's NRS 465.075 is a particularly relevant statutory reference for device/software assistance in gaming. Verify its current wording before making a Nevada-specific claim. No Canadian, UK, or global legal clearance was established in this environment; distribution territories and marketing claims require jurisdiction-specific review when relevant.

## Experience and accessibility decisions

- A useful first practice interaction should take less than a minute; avoid a sequence of marketing screens before the user can learn.
- Keep core actions reachable with one hand. Cards need large visible values and VoiceOver names, not color-only distinctions.
- Respect Dynamic Type, Reduce Motion, and the system color scheme. Keep essential controls available at accessibility text sizes.
- Give session pause, leave, and resume clear behavior. Do not punish interruptions or fabricate lost progress to drive a purchase.
- Offer optional haptics, with no requirement for sound to complete a drill.
- Use short feedback: the correct count and one calculation are more useful than repeated motivational paragraphs.
- Show honest progress drawn from completed sessions. Streaks and badges should support learning rather than become the main product.
