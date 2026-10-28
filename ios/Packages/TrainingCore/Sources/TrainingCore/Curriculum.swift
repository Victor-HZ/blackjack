import Foundation

public enum LessonVisual: String, Codable, Sendable {
    case values, cancellation, running, shoe, stacks, division, decisions, boundaries
}
public struct LessonStep: Codable, Equatable, Sendable, Identifiable {
    public let title: String
    public let body: String
    public let detail: String
    public var id: String { title }
    public init(_ title: String, _ body: String, detail: String = "") { self.title = title; self.body = body; self.detail = detail }
}
public struct LessonQuestion: Codable, Equatable, Sendable, Identifiable {
    public let prompt: String
    public let options: [String]
    public let correctIndex: Int
    public let explanation: String
    public var id: String { prompt }
    public init(_ prompt: String, options: [String], correct: Int, explanation: String) {
        self.prompt = prompt; self.options = options; correctIndex = correct; self.explanation = explanation
    }
}
public struct Lesson: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let symbol: String
    public let durationLabel: String
    public let isPremium: Bool
    public let visual: LessonVisual
    public let steps: [LessonStep]
    public let questions: [LessonQuestion]
    public init(id: String, title: String, subtitle: String, symbol: String, durationLabel: String = "3 min", isPremium: Bool, visual: LessonVisual, steps: [LessonStep], questions: [LessonQuestion]) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.symbol = symbol
        self.durationLabel = durationLabel; self.isPremium = isPremium; self.visual = visual; self.steps = steps; self.questions = questions
    }
}

public enum Curriculum {
    public static let lessons: [Lesson] = [
        Lesson(id: "hi-lo", title: "Three small numbers", subtitle: "Learn the Hi-Lo values.", symbol: "suit.spade.fill", isPremium: false, visual: .values,
               steps: [
                LessonStep("Give each card a value.", "In Hi-Lo, low cards add one. Middle cards add nothing. High cards subtract one.", detail: "2–6 → +1    7–9 → 0    10–A → −1"),
                LessonStep("Count values, not suits.", "A heart and a spade of the same rank have the same value. Ace is −1, even though its blackjack value can be 1 or 11."),
                LessonStep("Accuracy before pace.", "Say the value of one simulated card at a time. Build a reliable habit before making it faster.")
               ], questions: [
                LessonQuestion("What is a 5 worth in Hi-Lo?", options: ["−1", "0", "+1"], correct: 2, explanation: "Every 2, 3, 4, 5, or 6 adds one."),
                LessonQuestion("What is an ace worth?", options: ["−1", "+1", "+11"], correct: 0, explanation: "An ace subtracts one in Hi-Lo. Its blackjack hand value is separate."),
                LessonQuestion("Which group has a value of zero?", options: ["2, 3, 4", "7, 8, 9", "J, Q, K"], correct: 1, explanation: "Sevens, eights, and nines do not change the count.")
               ]),
        Lesson(id: "pairs", title: "Let pairs disappear", subtitle: "Cancel opposite values.", symbol: "rectangle.on.rectangle", isPremium: false, visual: .cancellation,
               steps: [
                LessonStep("One low. One high.", "A +1 card and a −1 card cancel. See them as zero instead of doing two separate updates.", detail: "5 + K → +1 − 1 → 0"),
                LessonStep("Keep the exceptions.", "Two low cards add two. Two high cards subtract two. A neutral card leaves the other card’s value unchanged."),
                LessonStep("Scan small groups.", "Cancel obvious pairs first, then count what remains. Never skip a card just because a group looks balanced.")
               ], questions: [
                LessonQuestion("What do 3 and Q add to the count?", options: ["−2", "0", "+2"], correct: 1, explanation: "+1 and −1 cancel."),
                LessonQuestion("What do 4 and 6 add?", options: ["0", "+1", "+2"], correct: 2, explanation: "Both are low cards, so +1 +1 = +2."),
                LessonQuestion("What do 9 and A add?", options: ["−1", "0", "+1"], correct: 0, explanation: "Nine is neutral. Ace subtracts one.")
               ]),
        Lesson(id: "running", title: "Carry the count", subtitle: "Keep one total in your head.", symbol: "plus.forwardslash.minus", isPremium: true, visual: .running,
               steps: [
                LessonStep("Start a fresh shoe at zero.", "Add the Hi-Lo value of every visible card to one running total. Keep that total between hands."),
                LessonStep("Negative is normal.", "If the count is −2 and a low card appears, the new count is −1. A high card would make it −3.", detail: "0 → 5 → K → 3 → 8     Count: +1"),
                LessonStep("A shuffle changes the starting point.", "Reset to zero when the cards are fully shuffled. Do not reset just because a hand ends. Hidden cards are counted only when revealed.")
               ], questions: [
                LessonQuestion("Your count is −3. A 4 appears. What is the new count?", options: ["−4", "−2", "+1"], correct: 1, explanation: "Four adds one: −3 +1 = −2."),
                LessonQuestion("When do you reset the running count?", options: ["After every hand", "After a complete shuffle", "Whenever the count is negative"], correct: 1, explanation: "The count carries between hands and resets for a newly shuffled shoe."),
                LessonQuestion("When should you count a face-down card?", options: ["Guess its value", "As soon as it is dealt", "When it is revealed"], correct: 2, explanation: "Only observed cards belong in your running count.")
               ]),
        Lesson(id: "shoe", title: "Build count stamina", subtitle: "Stay accurate through a shoe.", symbol: "rectangle.stack.fill", isPremium: true, visual: .shoe,
               steps: [
                LessonStep("Hi-Lo is balanced.", "A complete 52-card deck contains twenty +1 cards and twenty −1 cards. Its total is zero. The twelve neutral cards add nothing."),
                LessonStep("Use checkpoints.", "A deck’s final zero is a useful check, but errors can cancel. Our shoe drill checks every four cards so a lucky final total cannot hide mistakes."),
                LessonStep("Keep speed honest.", "First finish accurately. Then reduce the time between cards. Slower, correct practice is worth more than a fast guessed answer.")
               ], questions: [
                LessonQuestion("What is the Hi-Lo total of one complete deck?", options: ["−4", "0", "+4"], correct: 1, explanation: "Twenty +1 values and twenty −1 values balance to zero."),
                LessonQuestion("Does a final count of zero prove every update was correct?", options: ["Yes", "No"], correct: 1, explanation: "Two errors can cancel. Checkpoints reveal mistakes the final total might miss."),
                LessonQuestion("What should improve first?", options: ["Speed", "Accuracy", "Bet size"], correct: 1, explanation: "Train reliable counting before increasing pace.")
               ]),
        Lesson(id: "decks", title: "Read the cards left", subtitle: "Estimate decks remaining.", symbol: "square.stack.3d.up", isPremium: true, visual: .stacks,
               steps: [
                LessonStep("A deck is a unit.", "One standard deck has 52 cards. Half a deck has 26. Practice comparing a simulated stack to a full-deck marker."),
                LessonStep("Estimate what remains.", "For a true count, you need the undealt decks still in the shoe—not the original number of decks and not the discarded stack.", detail: "6 decks at the start − 4 dealt = 2 left"),
                LessonStep("Precision has limits.", "This course estimates to the nearest half deck. Real cards and shoes vary; a screen exercise is a learning model, not a calibrated measuring device.")
               ], questions: [
                LessonQuestion("About how many cards are in half a deck?", options: ["13", "26", "52"], correct: 1, explanation: "52 ÷2 = 26 cards."),
                LessonQuestion("Four decks have been dealt from a six-deck shoe. How many remain?", options: ["2", "4", "6"], correct: 0, explanation: "Six minus four leaves two undealt decks."),
                LessonQuestion("Which quantity is used for the true count?", options: ["Decks originally in the shoe", "Decks already dealt", "Decks remaining"], correct: 2, explanation: "The true count adjusts for the cards still available.")
               ]),
        Lesson(id: "true-count", title: "Put the count in context", subtitle: "Turn a running count into a true count.", symbol: "divide", isPremium: true, visual: .division,
               steps: [
                LessonStep("Divide by decks remaining.", "The same running count means more when fewer cards remain. True count = running count ÷ decks remaining.", detail: "+6 ÷ 3 decks = +2"),
                LessonStep("Keep your rounding consistent.", "These drills drop the decimal toward zero: +2.7 becomes +2; −2.7 becomes −2. Some index systems use different rounding rules. Follow the convention of the system you study."),
                LessonStep("A count is not a promise.", "A positive count describes card composition, not the next card. It cannot guarantee a winning hand or remove financial risk.")
               ], questions: [
                LessonQuestion("Running count +8, four decks left. True count?", options: ["+2", "+4", "+8"], correct: 0, explanation: "+8 ÷4 = +2."),
                LessonQuestion("Running count −5, two decks left. Using this course’s convention?", options: ["−3", "−2", "+2"], correct: 1, explanation: "−5 ÷2 = −2.5. Dropping the decimal toward zero gives −2."),
                LessonQuestion("Does a high true count guarantee the next hand wins?", options: ["Yes", "No"], correct: 1, explanation: "It does not predict a particular card or guarantee a win.")
               ]),
        Lesson(id: "decisions", title: "Separate skill from outcome", subtitle: "Build disciplined decisions.", symbol: "scope", isPremium: true, visual: .decisions,
               steps: [
                LessonStep("Basic strategy comes first.", "Learn the correct decision for your hand, the dealer’s upcard, and the table rules. A good decision can still lose a hand."),
                LessonStep("Rules change the right play.", "Deck count, soft-17 rules, surrender, and doubling restrictions matter. Our table coach teaches 4–8 deck US hole-card basic strategy."),
                LessonStep("Train one skill at a time.", "Practice card values, then running totals, then true counts. The app does not teach a real-money betting system or promise income.")
               ], questions: [
                LessonQuestion("A correct basic-strategy decision loses. Was it necessarily a bad decision?", options: ["Yes", "No"], correct: 1, explanation: "One outcome does not determine the quality of a decision."),
                LessonQuestion("Can different table rules change basic strategy?", options: ["Yes", "No"], correct: 0, explanation: "Rules affect which play has the best long-term expectation."),
                LessonQuestion("What does a practice score measure?", options: ["Guaranteed future winnings", "Accuracy on the exercises you completed", "Permission to use a device in a casino"], correct: 1, explanation: "It measures simulated practice, not financial performance or legal permission.")
               ]),
        Lesson(id: "boundaries", title: "Know the boundaries", subtitle: "Keep training separate from live play.", symbol: "checkmark.shield", isPremium: false, visual: .boundaries,
               steps: [
                LessonStep("Mental counting and devices differ.", "Remembering visible cards mentally is different from using an electronic aid during a live game. Device use can be prohibited by law and venue rules."),
                LessonStep("Train away from the table.", "Use this app only with its simulated cards. Do not use it during live casino play, or enter cards from a real game into another device."),
                LessonStep("Check local rules.", "Laws and venue policies vary. A venue may refuse service even where mental counting is lawful. This course is education, not legal advice or permission to play.")
               ], questions: [
                LessonQuestion("Where is this app intended to be used?", options: ["As a device beside a live casino game", "Away from live play, with simulated cards", "To bypass venue restrictions"], correct: 1, explanation: "The app is an offline training environment using simulated cards."),
                LessonQuestion("Are mental counting and electronic assistance legally identical everywhere?", options: ["Yes", "No"], correct: 1, explanation: "They can be treated differently. Applicable laws and venue rules must be checked."),
                LessonQuestion("Does finishing this course grant permission to count cards at any venue?", options: ["Yes", "No"], correct: 1, explanation: "Course completion does not replace local law or a venue’s policies.")
               ])
    ]
}
