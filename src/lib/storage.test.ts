import { describe, expect, it } from 'vitest';
import { availableActions, createGame, gameReducer } from './blackjack';
import type { Card, GameState } from './blackjack';
import { validateSavedPractice } from './storage';
import type { SavedPractice } from './storage';

const wrap = (game: GameState = createGame({ seed: 4 })): SavedPractice => ({
  version: 1, game, stats: { decisions: 10, correct: 8, drills: 7, correctDrills: 5 },
  showHints: true, showCount: false, bet: 25,
});
const card = (rank: Card['rank']): Card => ({ rank, suit: '♠' });

describe('saved practice validation', () => {
  it('accepts a fresh game and valid values after a JSON round trip', () => {
    expect(validateSavedPractice(JSON.parse(JSON.stringify(wrap())))).toBe(true);
  });

  it('accepts a zero draft bet while the custom bet field is blank', () => {
    expect(validateSavedPractice({ ...wrap(), bet: 0 })).toBe(true);
  });

  it('accepts actual engine transitions, including split, insurance, surrender, and settlement', () => {
    const scenarios: Card['rank'][][] = [
      ['8', '6', '8', '10', '3', '2', '5', '7'],
      ['10', 'A', '6', '9', '10'],
      ['A', '9', 'K', '7'],
      ['10', '10', '6', '9'],
    ];
    for (const ranks of scenarios) {
      let game = createGame({ shoe: ranks.map(card), seed: 3 });
      game = gameReducer(game, { type: 'deal', bet: 25 });
      expect(validateSavedPractice(wrap(game))).toBe(true);
      if (game.phase === 'insurance') {
        game = gameReducer(game, { type: 'insurance' });
        expect(validateSavedPractice(wrap(game))).toBe(true);
      }
      if (availableActions(game).includes('split')) {
        game = gameReducer(game, { type: 'split' });
        expect(validateSavedPractice(wrap(game))).toBe(true);
      }
      if (availableActions(game).includes('surrender')) {
        expect(validateSavedPractice(wrap(gameReducer(game, { type: 'surrender' })))).toBe(true);
      }
      while (game.phase === 'playing') {
        game = gameReducer(game, { type: 'stand' });
        expect(validateSavedPractice(wrap(game))).toBe(true);
      }
      expect(game.phase).toBe('settled');
      expect(validateSavedPractice(wrap(gameReducer(game, { type: 'shuffle' })))).toBe(true);
    }
  });

  it('allows bankroll exhaustion and preserved history after a rule change', () => {
    let game = createGame({ bankroll: 25, shoe: ['10', '10', '6', '9'].map(rank => card(rank as Card['rank'])) });
    game = gameReducer(gameReducer(game, { type: 'deal', bet: 25 }), { type: 'stand' });
    expect(game.bankroll).toBe(0);
    expect(validateSavedPractice(wrap(game))).toBe(true);
    const refreshed = { ...createGame({ bankroll: game.bankroll, rules: { decks: 8 } }), rounds: game.rounds, history: game.history };
    expect(validateSavedPractice(wrap(refreshed))).toBe(true);
  });

  it.each([null, undefined, {}, [], false, 3, 'saved'])('rejects missing or non-object data: %s', value => {
    expect(validateSavedPractice(value)).toBe(false);
  });

  it('rejects missing stats, impossible counts, and malformed preferences', () => {
    const samples: unknown[] = [
      { ...wrap(), version: 2 },
      { ...wrap(), stats: {} },
      { ...wrap(), stats: { decisions: 1, correct: 2, drills: 0, correctDrills: 0 } },
      { ...wrap(), stats: { decisions: 1, correct: 1, drills: 0, correctDrills: 1 } },
      { ...wrap(), stats: { decisions: 1.5, correct: 1, drills: 0, correctDrills: 0 } },
      { ...wrap(), showHints: 'yes' },
      { ...wrap(), showCount: null },
      { ...wrap(), bet: -1 },
      { ...wrap(), bet: Infinity },
    ];
    samples.forEach(sample => expect(validateSavedPractice(sample)).toBe(false));
  });

  it('rejects invalid cards, rule fields, numerics, and history entries', () => {
    const game = createGame({ seed: 1 });
    const corrupt: unknown[] = [
      { ...game, shoe: [{ rank: '11', suit: '♠' }] },
      { ...game, dealer: [{ rank: 'K', suit: 'red' }] },
      { ...game, rules: { ...game.rules, decks: 1 } },
      { ...game, rules: { ...game.rules, hitSoft17: 'false' } },
      { ...game, rules: { ...game.rules, blackjackPayout: 1.5 } },
      { ...game, rules: { decks: 6 } },
      { ...game, bankroll: -1 },
      { ...game, bankroll: NaN },
      { ...game, runningCount: 1.5 },
      { ...game, seed: -1 },
      { ...game, cutCard: undefined },
      { ...game, rounds: -1 },
      { ...game, insuranceBet: '0' },
      { ...game, activeHand: 1 },
      { ...game, history: [null] },
      { ...game, rounds: 1, history: [{ id: 1, bet: 25, profit: Infinity, bankroll: 1000, outcomes: ['win'] }] },
      { ...game, rounds: 1, history: [{ id: 1, bet: 25, profit: 25, bankroll: 1000, outcomes: ['unknown'] }] },
    ];
    corrupt.forEach(value => expect(validateSavedPractice({ ...wrap(), game: value })).toBe(false));
  });

  it('rejects active games that cannot safely resume', () => {
    const game = gameReducer(createGame({ shoe: ['10', '10', '6', '9'].map(rank => card(rank as Card['rank'])) }), { type: 'deal', bet: 25 });
    expect(game.phase).toBe('playing');
    const corrupt: unknown[] = [
      { ...game, hands: [] },
      { ...game, dealer: [] },
      { ...game, activeHand: 1 },
      { ...game, holeRevealed: true },
      { ...game, hands: [{ ...game.hands[0], bet: -10 }] },
      { ...game, hands: [{ ...game.hands[0], status: 'invalid' }] },
      { ...game, hands: [{ ...game.hands[0], fromSplit: undefined }] },
      { ...game, hands: [{ ...game.hands[0], payout: -1 }] },
      { ...game, phase: 'insurance' },
      { ...game, phase: 'settled' },
    ];
    corrupt.forEach(value => expect(validateSavedPractice({ ...wrap(), game: value })).toBe(false));
  });
});
