import type { Card, GameState, Hand, HandOutcome, RoundResult, Rules } from './blackjack';

export interface PracticeStats {
  decisions: number;
  correct: number;
  drills: number;
  correctDrills: number;
}

export interface SavedPractice {
  version: 1;
  game: GameState;
  stats: PracticeStats;
  showHints: boolean;
  showCount: boolean;
  bet: number;
}

const isObject = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value);
const isFiniteNumber = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value);
const isNonnegative = (value: unknown): value is number => isFiniteNumber(value) && value >= 0;
const isCount = (value: unknown): value is number => isNonnegative(value) && Number.isSafeInteger(value);
const isPositive = (value: unknown): value is number => isFiniteNumber(value) && value > 0;
const isBoolean = (value: unknown): value is boolean => typeof value === 'boolean';
const isOneOf = <T extends string | number>(value: unknown, allowed: readonly T[]): value is T => allowed.includes(value as T);
const outcomes: readonly HandOutcome[] = ['win', 'loss', 'push', 'blackjack', 'surrender'];

function validCard(value: unknown): value is Card {
  return isObject(value)
    && isOneOf(value.rank, ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'])
    && isOneOf(value.suit, ['♠', '♥', '♦', '♣']);
}

function validCards(value: unknown, minimum = 0): value is Card[] {
  return Array.isArray(value) && value.length >= minimum && value.length <= 416 && value.every(validCard);
}

function validRules(value: unknown): value is Rules {
  return isObject(value)
    && isOneOf(value.decks, [4, 6, 8])
    && isBoolean(value.hitSoft17)
    && isBoolean(value.doubleAfterSplit)
    && isBoolean(value.surrender)
    && isOneOf(value.blackjackPayout, ['3:2', '6:5']);
}

function validHand(value: unknown): value is Hand {
  return isObject(value)
    && validCards(value.cards, 2)
    && isPositive(value.bet)
    && isOneOf(value.status, ['playing', 'stood', 'bust', 'surrendered'])
    && isBoolean(value.fromSplit)
    && isBoolean(value.splitAces)
    && (value.outcome === undefined || isOneOf(value.outcome, outcomes))
    && (value.payout === undefined || isNonnegative(value.payout));
}

function validRound(value: unknown): value is RoundResult {
  return isObject(value)
    && isCount(value.id) && value.id > 0
    && isPositive(value.bet)
    && isFiniteNumber(value.profit)
    && isNonnegative(value.bankroll)
    && Array.isArray(value.outcomes) && value.outcomes.length >= 1 && value.outcomes.length <= 4
    && value.outcomes.every(outcome => isOneOf(outcome, outcomes));
}

function validGame(value: unknown): value is GameState {
  if (!isObject(value)
    || !validRules(value.rules)
    || !isOneOf(value.phase, ['betting', 'insurance', 'playing', 'settled'])
    || !isNonnegative(value.bankroll)
    || !validCards(value.shoe)
    || !validCards(value.dealer)
    || !Array.isArray(value.hands) || value.hands.length > 4 || !value.hands.every(validHand)
    || !isCount(value.activeHand)
    || !isFiniteNumber(value.runningCount) || !Number.isSafeInteger(value.runningCount)
    || !isBoolean(value.holeRevealed)
    || !isNonnegative(value.insuranceBet)
    || !isNonnegative(value.insurancePayout)
    || !isCount(value.rounds)
    || !Array.isArray(value.history) || value.history.length > 500 || !value.history.every(validRound)
    || typeof value.message !== 'string'
    || !isCount(value.seed) || value.seed > 0xffffffff
    || !isCount(value.cutCard) || value.cutCard > value.rules.decks * 52
  ) return false;

  if (value.hands.length === 0 ? value.activeHand !== 0 : value.activeHand >= value.hands.length) return false;
  const rounds = value.rounds;
  if (value.history.length > rounds || value.history.some(round => round.id > rounds)) return false;
  if (value.phase === 'betting' && (value.hands.length !== 0 || value.dealer.length !== 0 || value.holeRevealed)) return false;

  if (value.phase === 'playing' || value.phase === 'insurance') {
    if (value.dealer.length < 2 || value.hands.length === 0 || value.hands[value.activeHand].status !== 'playing' || value.holeRevealed) return false;
    if (value.hands.some(hand => hand.outcome !== undefined || hand.payout !== undefined)) return false;
    if (value.phase === 'insurance' && (value.dealer[0].rank !== 'A' || value.hands.length !== 1)) return false;
  }
  if (value.phase === 'settled') {
    if (value.dealer.length < 2 || value.hands.length === 0 || !value.holeRevealed || value.rounds === 0) return false;
    if (value.hands.some(hand => hand.status === 'playing' || hand.outcome === undefined || hand.payout === undefined)) return false;
  }
  return true;
}

/** Validate all persisted fields before exposing them to rendering or the game reducer. */
export function validateSavedPractice(value: unknown): value is SavedPractice {
  if (!isObject(value) || value.version !== 1 || !validGame(value.game)
    || !isObject(value.stats)
    || !isCount(value.stats.decisions)
    || !isCount(value.stats.correct)
    || !isCount(value.stats.drills)
    || !isCount(value.stats.correctDrills)
    || value.stats.correct > value.stats.decisions
    || value.stats.correctDrills > value.stats.drills
    || !isBoolean(value.showHints)
    || !isBoolean(value.showCount)
    || !isNonnegative(value.bet)
  ) return false;
  return true;
}
