# Studio Pro: one payment, useful training

The app is free to download. Introductory lessons and basic practice remain free. A **non-consumable in-app purchase** unlocks the complete learning path, additional drills, and advanced table rules. There is no subscription, consumable currency, real-money play, external checkout, advertising, or forced account creation.

The included StoreKit configuration uses **US$19.99 only as a local test price**. It is not a published offer or a verified recommendation for any market. The publisher chooses the actual price and availability in App Store Connect. The production paywall always displays `Product.displayPrice`, including the user’s local currency; it never invents a price when Apple cannot supply a product.

## Implementation

- `PurchaseStore` is the only source of paid access. Call `refresh()` when the app becomes active so changed Apple Account purchases and refunds are reconciled.
- Access comes from `.verified` StoreKit transactions and `Transaction.currentEntitlements`, including StoreKit’s signed local cache when available offline. There is no `UserDefaults` Pro flag, test argument, or release bypass.
- The transaction listener starts during initialization. Unfinished transactions are recovered at refresh. Verified content is delivered before `finish()` is called.
- Cancelled and pending purchases do not grant access. A pending approval can unlock later through `Transaction.updates`.
- Verified revocations/refunds remove access. An older asynchronous entitlement refresh cannot overwrite a newer verified transaction update.
- Restore is an explicit user action using `AppStore.sync()`. No automatic account-authentication prompt is triggered on launch.
- A failed product fetch leaves owned access intact. The app’s free content remains available, and the paywall offers a retry instead of a fake checkout.
- The paywall supports light/dark appearance, Dynamic Type, VoiceOver labels, large controls, and an optional completion callback. No animation or artificial countdown is used.

## Publisher configuration

The app currently uses a deliberate placeholder identity. Before distribution:

1. Join the Apple Developer Program and access a supported Mac with Xcode. Enrollment, identity verification, Apple agreements, signing, banking, and tax information must be completed by the account owner. Do not send credentials in chat or commit them to Git.
2. Choose a unique app Bundle ID. The project uses `com.example.blackjackstudio` as a starting value.
3. Register the app and create **one Non-Consumable** product in App Store Connect. The code reads `ProProductID` from Info.plist; the project’s default expands to `$(PRODUCT_BUNDLE_IDENTIFIER).pro`. Keep the actual product identifier consistent across the target, App Store Connect, and sandbox test setup. Product identifiers are not editable after creation.
4. Configure product name, descriptions, price, storefront availability, and the product’s App Review screenshot. Submit the first in-app purchase with the first app version as required by the current App Store Connect workflow.
5. Provide real publisher-owned HTTPS privacy and support pages. `PrivacyPolicyURL` and `TermsOfUseURL` in Info.plist open hosted versions when configured; readable offline fallbacks are included. In-app text is not a substitute for App Store Connect’s required privacy/support metadata.
6. Review the legal/privacy text, app age-rating questionnaire, and any simulated-gambling classification against the current Apple policies and your distribution jurisdictions. The app must not be marketed as universally legal in casinos or as a way to win money.
7. Family Sharing is **off** in the local StoreKit file. Decide whether to enable it in App Store Connect only after reviewing Apple’s current conditions; do not advertise Family Sharing unless it is actually enabled and tested. The purchase code honors signed ownership and revocation regardless of original purchase source.
8. Submit accurate App Review notes explaining the simulated training, free features, one-time Pro content, lack of real-money gambling, and how to reach the purchase and restore controls. Do not use fake live purchases or a hidden review-only entitlement override.

Apple’s current App Store agreements and policies control billing, commissions, tax, refunds, regional availability, and review outcomes. This project does not promise approval or revenue.

## Xcode StoreKit testing

`BlackjackStudio/Resources/BlackjackStudio.storekit` contains a local non-consumable test product, `com.example.blackjackstudio.pro`. Its schema follows Apple’s official Backyard Birds sample configuration (version 3), with the product type changed appropriately to `NonConsumable`. JSON syntax was checked in Linux; Xcode/StoreKit execution remains a separate required check.

For local testing on a Mac:

1. Match the local product ID to your Debug build’s `ProProductID` (or retain the placeholder Bundle ID for simulator-only tests).
2. Select the local `.storekit` file in the development scheme’s Run → Options → StoreKit Configuration. This is a development convenience, not a production product registration.
3. Use Xcode’s StoreKit transaction manager to clear transactions between cases, trigger refunds, and resolve Ask to Buy requests.
4. For real sandbox or TestFlight testing, **disable local StoreKit configuration** and use the actual product registered in App Store Connect. TestFlight billing is sandbox billing; no live charge is expected.
5. Do not treat the local configuration as proof of a working App Store Connect listing, production purchase, signing setup, or release.

## Required purchase test matrix

None of the following StoreKit/iOS runtime cases has been executed on this Linux machine. Complete and record them on a Mac/simulator plus a physical iPhone/TestFlight before release.

| Case | Expected result |
| --- | --- |
| New customer, no transactions | Free app usable; Pro features consistently gated; honest localized price |
| Successful one-time purchase | Apple confirmation appears; verified Pro unlocks; purchase is finished after delivery |
| User cancels | No unlock, no charge confirmation, no error nag |
| Ask to Buy / pending | Clear pending message; no early unlock; later approved update unlocks |
| Failed or unverified transaction | No unlock; recoverable message; no unverified transaction acknowledged |
| Existing purchase, fresh install | Signed current entitlement restores ownership without requiring a local flag |
| Restore with owning Apple Account | Pro unlocks; restore does not clear practice data |
| Restore with no purchase | Informative no-purchase message; free app unaffected |
| Restore cancelled / network unavailable | No false success; user can retry |
| Offline after owned purchase | Cached verified entitlement permits Pro when StoreKit makes it available |
| Offline before first product load | No invented price or purchase; free training works; retry is available |
| App terminated during purchase delivery | Unfinished transaction is recovered and delivered once on next launch |
| Refund or revocation | Signed update removes paid access; completed training records remain intact |
| Apple Account change | Foreground refresh reflects the active account’s signed entitlement |
| Region or currency change | App Store’s localized product price and availability are respected |
| UI accessibility | Largest Dynamic Type sizes, VoiceOver, light/dark, landscape/iPad, and 44-point tap controls remain usable |

## Verified implementation reference

Apple’s official sample was inspected at commit `1843d5655bf884b501e2889ad9862ec58978fdbe`:

- [BirdBrain.swift: verification, transaction updates, revocation, and finishing](https://github.com/apple/sample-backyard-birds/blob/1843d5655bf884b501e2889ad9862ec58978fdbe/Multiplatform/Shop/BirdBrain.swift)
- [RestorePurchasesButton.swift: explicit AppStore.sync](https://github.com/apple/sample-backyard-birds/blob/1843d5655bf884b501e2889ad9862ec58978fdbe/Multiplatform/Account/RestorePurchasesButton.swift)
- [Store.storekit: local StoreKit schema](https://github.com/apple/sample-backyard-birds/blob/1843d5655bf884b501e2889ad9862ec58978fdbe/Misc/Store.storekit)

The sample contains consumables/subscriptions; this app implements non-consumable ownership rather than copying those business rules. Direct Apple policy pages were blocked by this environment’s network proxy, so current publishing policy still needs live verification. See `RESEARCH.md` for the research status and policy source links.
