# Blackjack Studio

## Native iOS app

The native SwiftUI app is in [`ios/`](ios/README.md), with lessons, drills, StoreKit Pro, an Xcode project, and release instructions. See the [iOS validation status](ios/README.md#validation-and-honest-release-status) before publishing. The existing web app below remains available.

A responsive blackjack practice web app with an interactive table, basic-strategy coaching, Hi-Lo card counting, and locally saved progress. Built with React, TypeScript, and Vite.

The requested reference is [Blackjack Wiz – Card Counting](https://apps.apple.com/ca/app/blackjack-wiz-card-counting/id6788486381). Its App Store listing and screenshots were inaccessible from the development environment. This implementation uses original branding and visual assets; exact feature and visual parity has **not** been verified.

## Run locally

Requires Node.js 22.12+ (validated with Node 24) and npm.

```sh
npm ci
npm run dev
```

Vite defaults to port 5173. The app is entirely client-side: no accounts, API credentials, database, or payment service are required. Fonts are bundled locally. Current hands, preferences, and statistics are saved in the browser's local storage on the current origin; there is no cross-device sync.

## Features

- Blackjack with hit, stand, double, split (up to four hands), insurance, and late surrender.
- Four-, six-, and eight-deck shoes with a 75% penetration cut card and automatic reshuffle between rounds.
- Configurable soft-17 rules, double after split, surrender, and 3:2 or 6:5 blackjack payouts.
- Split aces get one extra card. Split 21 pays as an ordinary win; resplitting aces is not allowed.
- Basic-strategy advice that accounts for the current rules, available actions, and bankroll. Hints can be hidden for unassisted practice.
- Live running and true Hi-Lo counts; the dealer's hole card is excluded from the running count until revealed.
- Hard-total, soft-total, and pair strategy charts with an interactive hand lookup.
- Twenty-card counting drills with immediate feedback and accuracy tracking.
- Practice bankroll history, strategy accuracy, counting accuracy, and CSV export of the latest 500 rounds.
- Keyboard actions, responsive mobile navigation, and dialog focus management.
- Validation of saved state and a recovery path for corrupted local storage.

All bankroll values are practice credits. The strategy engine covers total-dependent **4–8 deck US hole-card rules**. It does not implement single/double-deck deviations, European no-hole-card rules, composition-dependent strategy, or count-based strategy deviations. Automatic count displays are a training aid, not a camera or live casino card-recognition feature.

## Verification

```sh
npm test          # Engine, payout, strategy, count, and persistence tests
npm run build    # TypeScript check and production build
npm run test:e2e # Chromium desktop/mobile functional tests
```

Browser tests use `/usr/bin/chromium` in the cloud environment. Elsewhere, set `PLAYWRIGHT_CHROMIUM_EXECUTABLE` to your Chromium or Chrome binary. Playwright starts the development server when required. The test browser disables its sandbox for the container; this is test-runner configuration, not an app runtime requirement.

Production output is generated in `dist/` and can be served by any static hosting provider. `npm run preview` serves a local production preview. No deployment has been performed.

## Code map

- `src/App.tsx`: application navigation, table, coaching, settings, history, and persistence integration.
- `src/lib/blackjack.ts`: deterministic game reducer, money settlement, shoe, scoring, and basic strategy.
- `src/lib/storage.ts`: validation of saved games and statistics.
- `src/components/TrainingTools.tsx`: strategy charts, hand lookup, and counting drills.
- `src/styles.css`: responsive table and application styles.
- `e2e/app.spec.ts`: browser tests exercising actual user workflows.

## Cloud environment

Work in the existing `/workspace/blackjack` checkout. Cloud tasks already have an isolated environment; no extra Git worktree is needed. Install with `npm ci`, then run `npm run dev -- --port 5173 --strictPort`. Server processes must be restarted in future tasks even when dependencies are retained in the environment snapshot.
