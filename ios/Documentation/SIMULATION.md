# Native simulation sessions

Simulation is a separate, finite practice table available from Practice and Table. It does not change a user's free-play shoe, practice points, or table statistics.

## Session flow

1. Choose 10, 25, or 50 rounds and a feedback mode. Running-count checks are optional.
2. Play each automatically dealt round. All legal table actions, including insurance and splits, use the existing blackjack engine.
3. Review the settled hand. With count checks enabled, start a recall check; the cards disappear before an answer can be entered.
4. Complete the checkpoint before dealing the next round. Split hands count as one round. Naturals still count as a round, without inventing a strategy decision.
5. Review strategy accuracy and count accuracy, then retry missed decisions or open a counting drill/strategy reference. A fresh session can use the same configuration.

Guided practice explains decisions after the first attempt. Skill test withholds correctness, recommendations, and count answers until the final review. Neither mode reveals the dealer's hole card during play. A new-shoe message tells the user when to reset the count.

Results grade basic-strategy decisions under the session's actual rules and legal actions, plus running-count answers. Insurance is assessed against basic strategy's recommendation to decline. Count-based strategy deviations are not scored. Winning a hand is not evidence of making a correct decision, and losses do not lower a strategy score. One-point simulated stakes and sufficient starting practice points allow every selected session to finish without deposits or a reset.

## Learning and persistence

- First attempts determine the saved result. Review quizzes do not alter the original score.
- The review retains each missed hand, dealer upcard, selected action, recommended action, and explanation.
- Missed counts lead to the running-count drill. Missed decision types identify the relevant strategy topic.
- In-progress sessions resume after closing the screen or relaunching. Ending a session requires confirmation; unfinished sessions do not create a completed result.
- Completed sessions appear in Progress, count toward practice activity, and are included in progress export/deletion. Foreground practice time contributes to the daily goal; background time does not.
- Existing saved progress migrates without losing lessons, drills, or the free-play table. Up to 100 completed native simulation summaries are retained.

This is offline training with automatically generated cards, never a tool for entering or tracking a live game. No money, payouts, deposits, casino connections, or profit promises are provided.

## Validation

Portable tests exercise session limits, state-transition gates, first-attempt scoring, natural/split/insurance behavior, count checkpoints, shoe resets, malformed restoration, and saved-state migration. Native UI scenarios are prepared in `AppFlowTests.swift`; Apple SDK compilation and native rendering still require Xcode. Browser tests cover the corresponding React simulation separately and do not establish native rendering correctness.
