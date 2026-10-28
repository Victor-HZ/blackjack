import { describe, expect, it } from 'vitest';
import { availableActions, basicStrategy, createGame, createShoe, gameReducer, hiLo, score, seededRandom, trueCount, type Card, type Rank } from './blackjack';
const cards = (...ranks: Rank[]): Card[] => ranks.map(rank => ({ rank, suit: '♠' }));
const deal = (shoe: Card[], bet = 100, rules = {}) => gameReducer(createGame({ shoe, rules, seed: 10 }), { type: 'deal', bet });

describe('card math and shoe', () => {
  it('reduces multiple aces correctly and distinguishes soft totals', () => {
    expect(score(cards('A','A','9'))).toEqual({ total: 21, soft: true, blackjack: false, bust: false });
    expect(score(cards('A','6','10'))).toEqual({ total: 17, soft: false, blackjack: false, bust: false });
    expect(score(cards('K','Q','2')).bust).toBe(true);
    expect(score(cards('A','Q')).blackjack).toBe(true);
  });
  it('builds complete, reproducible shuffled shoes', () => {
    const first = createShoe(6, seededRandom(123));
    expect(first).toHaveLength(312);
    expect(first).toEqual(createShoe(6, seededRandom(123)));
    expect(first.filter(c => c.rank === 'A' && c.suit === '♥')).toHaveLength(6);
    expect(first).not.toEqual(createShoe(6, seededRandom(124)));
    expect(first.reduce((sum, card) => sum + hiLo(card), 0)).toBe(0);
  });
  it('normalizes running count by remaining decks', () => {
    expect(trueCount({ runningCount: 8, shoe: createShoe(2) })).toBe(4);
  });
});

describe('US-hole-card blackjack play', () => {
  it('keeps the hole card out of the running count until revealed', () => {
    const state = deal(cards('10','6','7','10','10'));
    expect(state.phase).toBe('playing');
    expect(state.holeRevealed).toBe(false);
    expect(state.runningCount).toBe(0);
    const settled = gameReducer(state, { type: 'stand' });
    expect(settled.runningCount).toBe(-2);
    expect(settled.holeRevealed).toBe(true);
    expect(settled.bankroll).toBe(1100);
    expect(state.bankroll).toBe(900);
    expect(state.dealer).toHaveLength(2);
  });
  it.each([['3:2',1150],['6:5',1120]] as const)('pays natural blackjack at %s', (blackjackPayout, bankroll) => {
    const state = deal(cards('A','10','K','Q'),100,{ blackjackPayout });
    expect(state.phase).toBe('settled');
    expect(state.hands[0].outcome).toBe('blackjack');
    expect(state.bankroll).toBe(bankroll);
  });
  it('pushes equal totals and returns the original wager', () => {
    const state = gameReducer(deal(cards('10','10','8','8')), { type: 'stand' });
    expect(state.hands[0].outcome).toBe('push');
    expect(state.bankroll).toBe(1000);
    expect(state.history[0].profit).toBe(0);
    expect(state.message).toBe('Push. Your bet is returned.');
  });
  it('settles a player bust without drawing unnecessary dealer cards', () => {
    const state = gameReducer(deal(cards('10','6','7','5','K')), { type: 'hit' });
    expect(state.hands[0].outcome).toBe('loss');
    expect(state.bankroll).toBe(900);
    expect(state.dealer).toHaveLength(2);
    expect(state.history[0].profit).toBe(-100);
  });
  it('doubles the wager and takes exactly one card', () => {
    const state = gameReducer(deal(cards('5','6','6','10','10','10')), { type: 'double' });
    expect(state.hands[0].cards).toHaveLength(3);
    expect(state.hands[0].bet).toBe(200);
    expect(state.bankroll).toBe(1200);
    expect(state.history[0].bet).toBe(200);
  });
  it('splits aces to one card each, paying split 21 as an ordinary win', () => {
    const state = gameReducer(deal(cards('A','10','A','7','K','9')), { type: 'split' });
    expect(state.phase).toBe('settled');
    expect(state.hands.map(hand => hand.cards.length)).toEqual([2,2]);
    expect(state.hands.map(hand => hand.outcome)).toEqual(['win','win']);
    expect(state.bankroll).toBe(1200);
  });
  it('advances through split hands and respects no double after split', () => {
    let state = gameReducer(deal(cards('8','10','8','7','3','2','10','9'),100,{doubleAfterSplit:false}), { type: 'split' });
    expect(state.activeHand).toBe(0);
    expect(availableActions(state)).not.toContain('double');
    expect(availableActions(state)).not.toContain('surrender');
    state = gameReducer(state, { type:'hit' });
    expect(state.activeHand).toBe(1);
    expect(state.phase).toBe('playing');
    state = gameReducer(state, { type:'hit' });
    state = gameReducer(state, { type:'stand' });
    expect(state.phase).toBe('settled');
    expect(state.bankroll).toBe(1200);
  });
  it('late surrender returns half the stake after dealer peek', () => {
    const state = gameReducer(deal(cards('10','10','6','7')), { type:'surrender' });
    expect(state.bankroll).toBe(950);
    expect(state.hands[0].outcome).toBe('surrender');
    expect(state.history[0].profit).toBe(-50);
  });
  it.each([1.07, 1.13, 1.15, 25.51])('keeps fractional-wager payouts and bankroll accounting consistent for %s', bet => {
    const state = gameReducer(deal(cards('10','10','6','7'), bet), { type:'surrender' });
    const round = state.history[0];
    const expectedBankroll = Math.round((1000 - bet + state.hands[0].payout!) * 100) / 100;
    expect(state.bankroll).toBe(expectedBankroll);
    expect(Math.round((state.bankroll - 1000) * 100) / 100).toBe(round.profit);
  });
  it('offers insurance before settling dealer blackjack, and pays it 2:1', () => {
    const initial = deal(cards('9','A','8','K'));
    expect(initial.phase).toBe('insurance');
    expect(initial.holeRevealed).toBe(false);
    const insured = gameReducer(initial, { type:'insurance' });
    expect(insured.insuranceBet).toBe(50);
    expect(insured.insurancePayout).toBe(150);
    expect(insured.bankroll).toBe(1000);
    expect(insured.history[0].profit).toBe(0);
    expect(insured.message).toBe('Round breaks even. No credits won or lost.');
    expect(gameReducer(initial, { type:'declineInsurance' }).bankroll).toBe(900);
  });
  it('loses insurance when dealer does not have a natural', () => {
    let state = gameReducer(deal(cards('10','A','9','6')), { type:'insurance' });
    expect(state.phase).toBe('playing');
    state = gameReducer(state, { type:'stand' });
    expect(state.bankroll).toBe(1050);
    expect(state.insurancePayout).toBe(0);
  });
  it('pushes player and dealer naturals', () => {
    const state = gameReducer(deal(cards('A','A','K','Q')), { type:'declineInsurance' });
    expect(state.bankroll).toBe(1000);
    expect(state.hands[0].outcome).toBe('push');
  });
  it('hits soft 17 only when configured', () => {
    const shoe = cards('10','A','8','6','4');
    const s17 = gameReducer(gameReducer(deal(shoe), { type:'declineInsurance' }), { type:'stand' });
    const h17 = gameReducer(gameReducer(deal(shoe,100,{hitSoft17:true}), { type:'declineInsurance' }), { type:'stand' });
    expect(s17.dealer).toHaveLength(2);
    expect(s17.bankroll).toBe(1100);
    expect(h17.dealer).toHaveLength(3);
    expect(h17.bankroll).toBe(900);
  });
  it('rejects impossible bets, insufficient funds, and actions outside a hand', () => {
    const state = createGame({ bankroll: 100, shoe: cards('5','6','6','10','K') });
    expect(gameReducer(state, { type:'deal',bet:101 })).toBe(state);
    expect(gameReducer(state, { type:'deal',bet:NaN })).toBe(state);
    expect(gameReducer(state, { type:'hit' })).toBe(state);
    const active = gameReducer(state, { type:'deal', bet:100 });
    expect(availableActions(active)).not.toContain('double');
    expect(gameReducer(active, { type:'double' })).toBe(active);
    expect(gameReducer(active, { type:'shuffle' })).toBe(active);
  });
  it('keeps transitions deterministic without mutating the previous state', () => {
    const state = deal(cards('5','6','6','10','10','10'));
    const snapshot = JSON.stringify(state);
    expect(gameReducer(state, {type:'double'})).toEqual(gameReducer(state, {type:'double'}));
    expect(JSON.stringify(state)).toBe(snapshot);
  });
});

describe('multi-deck basic strategy', () => {
  const up = (rank: Rank): Card => ({ rank, suit:'♦' });
  it.each([
    [['8','8'],'10','split'], [['A','A'],'A','split'], [['10','10'],'6','stand'],
    [['5','5'],'6','double'], [['10','6'],'10','surrender'], [['10','2'],'3','hit'],
    [['10','2'],'4','stand'], [['A','7'],'9','hit'], [['A','7'],'6','double'],
    [['A','8'],'6','stand'], [['5','6'],'A','hit'], [['9','9'],'7','stand'],
  ] as [Rank[],Rank,string][])('recommends for %s versus %s', (hand,dealer,expected) => {
    expect(basicStrategy(cards(...hand), up(dealer)).action).toBe(expected);
  });
  it('uses H17 exceptions', () => {
    expect(basicStrategy(cards('A','8'),up('6'),{hitSoft17:true}).action).toBe('double');
    expect(basicStrategy(cards('5','6'),up('A'),{hitSoft17:true}).action).toBe('double');
    expect(basicStrategy(cards('10','7'),up('A'),{hitSoft17:true}).action).toBe('surrender');
  });
  it('respects unavailable doubles, splits, and surrenders', () => {
    expect(basicStrategy(cards('A','7'),up('6'),{}, {canDouble:false}).action).toBe('stand');
    expect(basicStrategy(cards('5','6'),up('6'),{}, {canDouble:false}).action).toBe('hit');
    expect(basicStrategy(cards('8','8'),up('10'),{}, {canSplit:false,canSurrender:false}).action).toBe('hit');
    expect(basicStrategy(cards('10','6'),up('10'),{surrender:false}).action).toBe('hit');
    expect(basicStrategy(cards('2','2'),up('2'),{doubleAfterSplit:false}).action).toBe('hit');
  });
});
