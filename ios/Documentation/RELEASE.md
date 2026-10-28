# Build and publish Blackjack Studio

The repository contains a native SwiftUI iPhone/iPad app, local Swift packages, a deterministic Xcode project, a local StoreKit configuration, and a macOS CI workflow. It is not a web view wrapper.

**Publication has not been performed.** Linux can validate the portable Swift code and project syntax, but it cannot compile SwiftUI/StoreKit against the iOS SDK, run an iOS Simulator, sign an app, or establish App Store approval. Complete the native and publisher steps below before treating this as a release candidate.

## 1. Open the native project

On a Mac with a current supported Xcode installation:

```sh
cd /path/to/blackjack
python3 ios/scripts/generate-xcode-project.py
open ios/BlackjackStudio.xcodeproj
```

Select the **BlackjackStudio** scheme and an iPhone simulator. This scheme uses Debug and the local `BlackjackStudio.storekit` file for StoreKit testing. It needs no Apple account to run on a simulator. The **BlackjackStudio Release** scheme uses Release and attaches no local StoreKit configuration.

The deployment target is iOS 17.0; Swift language mode is 5 with strict-concurrency checking. A contemporary Swift 6 compiler can build that language mode. The deployment target is different from Apple's required submission SDK: check the current [upcoming submission requirements](https://developer.apple.com/news/upcoming-requirements/) before archiving. This environment could not retrieve the current Apple policy pages, so no unverified SDK deadline is assumed here.

The project references only local packages:

- `ios/Packages/BlackjackCore`
- `ios/Packages/TrainingCore`
- `ios/Packages/StudioCore`

No CocoaPods, external package resolution, backend credentials, or account creation is required for the app.

## 2. Keep the project in sync

Project membership is generated from files under `ios/BlackjackStudio/`, `ios/BlackjackStudioUITests/`, and optional `ios/BlackjackStudioTests/`. After adding, moving, or deleting Swift source files:

```sh
python3 ios/scripts/generate-xcode-project.py
python3 ios/scripts/generate-xcode-project.py --check
```

Edit the generator or `ios/Config/*.xcconfig` for permanent configuration changes. Manual edits inside the generated `.xcodeproj` are replaced by the next generator run. Developer identities and public URLs belong in `Config/Publisher.xcconfig`, which is preserved by regeneration.

The asset catalog and `PrivacyInfo.xcprivacy` are bundled. `Info.plist` is processed as the app manifest. The local `.storekit` file is copied into the **UI-test bundle only**, so `SKTestSession(configurationFileNamed: "BlackjackStudio")` can load it. It is **not** copied into the application bundle. Shared schemes are checked into source control; user-specific Xcode state is not required.

## 3. Validate the native build

Run portable tests on macOS or the verified Linux Swift toolchain:

```sh
for package in BlackjackCore TrainingCore StudioCore; do
  swift test --package-path "ios/Packages/$package" --jobs 4
done
```

On Linux, `ios/scripts/install-swift-linux.sh` installs the official Swift 6.2 toolchain only after its release signature and SHA-256 pass. The toolchain is at `/workspace/.toolchains/swift-6.2/usr/bin/swift`. Use writable `--cache-path`, `--config-path`, `--security-path`, and `--scratch-path` options when the shell sandbox cannot write to user-level SwiftPM directories. Provenance is recorded beside the installer.

On macOS, choose an available device from `xcrun simctl list devices available`, then use its UUID:

```sh
xcodebuild build \
  -project ios/BlackjackStudio.xcodeproj \
  -scheme 'BlackjackStudio Release' \
  -configuration Release \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UUID' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project ios/BlackjackStudio.xcodeproj \
  -scheme BlackjackStudio \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UUID' \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/BlackjackStudio.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

The GitHub workflow `.github/workflows/ios.yml` runs package tests, a Release simulator build, and native UI tests on `macos-latest`. It selects an available iPhone dynamically and preserves `.xcresult` diagnostics. The workflow was prepared but was not pushed, triggered, or claimed to have passed remotely.

Before release, also exercise a physical iPhone, an iPad, small screens, large Dynamic Type, VoiceOver, dark mode, Reduce Motion, interrupted sessions, background/foreground transitions, offline launch, and local-data recovery. Simulator screenshots or browser design previews do not replace those checks.

## 4. Set the publisher's production identity

Edit `ios/Config/Publisher.xcconfig`:

```xcconfig
STUDIO_BUNDLE_IDENTIFIER = com.yourregisteredbusiness.blackjackstudio
DEVELOPMENT_TEAM = YOURTEAMID
PRO_PRODUCT_ID = $(STUDIO_BUNDLE_IDENTIFIER).pro
STUDIO_PRIVACY_POLICY_URL = https:/$()/your-real-domain.com/privacy
STUDIO_TERMS_OF_USE_URL = https:/$()/your-real-domain.com/terms
STUDIO_SUPPORT_URL = https:/$()/your-real-domain.com/support
```

These examples are placeholders, not registered accounts or hosted pages. `DEVELOPMENT_TEAM` must be the publisher's actual 10-character Team ID. The `$()` in HTTPS addresses expands to an empty string and prevents xcconfig from treating `//` as a comment.

Register the exact bundle identifier in the Apple Developer account and create the app record in App Store Connect. In Xcode, select the publisher's team for signing and let Xcode manage valid provisioning, or use the publisher's established signing process. Do not put signing certificates, passwords, private keys, or App Store Connect API credentials in the repository or app bundle.

Publish the privacy, terms, and support pages at the configured addresses. The in-app privacy text does not make the App Store's required public privacy/support URLs exist. Check the pages as a signed-out user and provide a working support contact.

Run the configuration gate:

```sh
ios/scripts/validate-release.sh
```

It deliberately rejects the default example bundle/product IDs, missing team, missing or placeholder public URLs, invalid version/build values, missing/transparent App Store icon, mismatched privacy declarations, and a Release scheme using local StoreKit testing. Passing this gate verifies configuration shape; it does not verify ownership, URL availability, product registration, signing, native compilation, purchases, or App Review approval.

## 5. Configure and test the paid unlock

See `MONETIZATION.md` for the implemented purchase behavior. In App Store Connect:

1. Complete the publisher's paid-app agreements, tax, and banking setup.
2. Create the nonconsumable product whose exact ID is `PRO_PRODUCT_ID`.
3. Set the intended storefronts, localized name/description, price, and review screenshot. The local StoreKit test price is not a live App Store price.
4. Confirm the app displays StoreKit's localized price and a clear one-time purchase description.
5. Test success, cancel, pending/Ask to Buy, failed verification, offline access for an existing owner, restore on reinstall/another device, and revocation/refund behavior.
6. Use sandbox/TestFlight with the actual configured product before submitting. Local `.storekit` tests do not verify the App Store Connect product.

If you change the bundle/product identifier, update the local `.storekit` product ID as well to keep Debug testing consistent. Do not attach that test configuration to the Release scheme. Do not unlock paid content through a production launch argument or a preferences flag.

## 6. Privacy, age rating, and educational scope

The app is designed for local progress and preferences, with no analytics SDK, tracking, ads, accounts, or developer backend. The privacy manifest currently declares no collected data and no tracking. It declares required-reason system-boot-time access, reason **35F9.1**, solely for measuring elapsed time between events in the app's drills. It does not currently use UserDefaults or file metadata timestamps. Revisit this manifest and App Store privacy answers if the implementation changes.

StoreKit purchase processing is handled by Apple. Answer App Store Connect's privacy questionnaire from the final shipped implementation and any added SDKs, rather than copying this design assumption blindly.

Answer the age-rating questionnaire honestly for simulated blackjack and gambling-related educational material. Do not assume a teaching purpose automatically creates a child-friendly rating. There are no real-money stakes, cash prizes, gambling affiliate links, or live-casino card-entry tools. The product should teach mental skills using generated practice cards; do not market it as a device to use while gambling or promise profits.

The current official guideline/statute pages were blocked during this work. `RESEARCH.md` records what was actually verified and what still requires current authoritative review. The app name, logo, screens, and store screenshots must remain original; this is not affiliated with Blackjack Wiz.

## 7. Archive and submit on the publisher's Mac

After the native, device, purchase, metadata, and configuration checks pass:

```sh
xcodebuild archive \
  -project ios/BlackjackStudio.xcodeproj \
  -scheme 'BlackjackStudio Release' \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/BlackjackStudio.xcarchive
```

A signed archive requires the publisher's real signing configuration. In Xcode Organizer, validate the archive, distribute to App Store Connect, then complete TestFlight and App Review submission through the publisher's account. Increment the build number for each uploaded build.

Supply original screenshots from the actual app, an accurate description of free and paid functionality, the final age/privacy answers, support and privacy URLs, copyright information, and review notes explaining the educational/offline purpose and how to reach and restore the Pro purchase. No review account is needed because the app has no account system.

No App Store submission, payment agreement, signing identity, live product, price, hosted legal page, revenue forecast, or approval is created by the files in this repository. Those are publisher-controlled release prerequisites.
