# BlackjackCore

A portable Foundation-only Swift package used by the iOS app. State is a Codable value; the reducer does not mutate its input. No networking, account data, purchase state, or UI framework is part of this module.

```swift
var game = GameState(seed: 42)
game = GameEngine.reduce(game, .deal(betCents: 2_500))
let advice = BasicStrategy.recommend(in: game)
let allowed = GameEngine.availableMoves(in: game)
```

- All stake, payout, and bankroll arithmetic uses integer hundredths of virtual practice credits. A 25-credit stake is `2_500` cents. Half-cent payouts round up consistently in both bankroll and round results.
- US hole-card rules; 4, 6, or 8 decks; stand/hit soft 17; optional double after split and late surrender; 3:2 or 6:5 natural payouts.
- Split to at most four hands. Split aces receive one card, cannot be resplit, and a split 21 pays as an ordinary win.
- The dealer peeks before play. Insurance is offered on an ace before the peek and pays 2:1.
- The dealer hole card enters the Hi-Lo running count only when revealed. The true count uses undealt decks, with a quarter-deck denominator floor at exhaustion.
- A cut card at 75% penetration triggers a deterministic fresh shoe between rounds. A seed or an explicit shoe supports repeatable tests.
- Basic strategy is total-dependent and constrained by the legal moves available to the active hand. Single/double-deck, composition-dependent, European no-hole-card, and count-based deviations are not supported.
- Call `game.isValidForRestore` after decoding stored state. The reducer also rejects structurally invalid states.

Run `swift test` in this package on macOS or Linux. The iOS app's SwiftUI and StoreKit layers still require Xcode on macOS for their build and UI tests.
