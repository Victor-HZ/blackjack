/** Blackjack rules and deterministic game transitions. Monetary values are practice credits. */
export type Rank = 'A' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | '10' | 'J' | 'Q' | 'K';
export type Suit = '♠' | '♥' | '♦' | '♣';
export interface Card { rank: Rank; suit: Suit }
export interface Rules {
  decks: 1 | 2 | 4 | 6 | 8;
  hitSoft17: boolean;
  doubleAfterSplit: boolean;
  surrender: boolean;
  blackjackPayout: '3:2' | '6:5';
}
export const DEFAULT_RULES: Rules = { decks: 6, hitSoft17: false, doubleAfterSplit: true, surrender: true, blackjackPayout: '3:2' };
export type Move = 'hit' | 'stand' | 'double' | 'split' | 'surrender';
export type HandOutcome = 'win' | 'loss' | 'push' | 'blackjack' | 'surrender';
export interface Hand {
  cards: Card[];
  bet: number;
  status: 'playing' | 'stood' | 'bust' | 'surrendered';
  fromSplit: boolean;
  splitAces: boolean;
  outcome?: HandOutcome;
  /** Total credits returned, including the original stake. */
  payout?: number;
}
export interface RoundResult { id: number; bet: number; profit: number; bankroll: number; outcomes: HandOutcome[] }
export interface GameState {
  rules: Rules;
  phase: 'betting' | 'insurance' | 'playing' | 'settled';
  bankroll: number;
  shoe: Card[];
  dealer: Card[];
  hands: Hand[];
  activeHand: number;
  runningCount: number;
  holeRevealed: boolean;
  insuranceBet: number;
  insurancePayout: number;
  rounds: number;
  history: RoundResult[];
  message: string;
  seed: number;
  cutCard: number;
}
export type GameAction = { type: 'deal'; bet: number } | { type: Move | 'insurance' | 'declineInsurance' } | { type: 'shuffle'; shoe?: Card[] };
const RANKS: Rank[] = ['A','2','3','4','5','6','7','8','9','10','J','Q','K'];
const SUITS: Suit[] = ['♠','♥','♦','♣'];
export const cardValue = (card: Card): number => card.rank === 'A' ? 11 : ['J','Q','K'].includes(card.rank) ? 10 : Number(card.rank);
export function score(cards: readonly Card[]) {
  let total = cards.reduce((sum, card) => sum + cardValue(card), 0);
  let aces = cards.filter(card => card.rank === 'A').length;
  while (total > 21 && aces > 0) { total -= 10; aces--; }
  return { total, soft: aces > 0, blackjack: cards.length === 2 && total === 21, bust: total > 21 };
}
export function hiLo(card: Card): number { const n = cardValue(card); return n >= 2 && n <= 6 ? 1 : n >= 10 ? -1 : 0; }
/** Fractional true count; round toward zero when using whole-number indices. */
export function trueCount(state: Pick<GameState, 'runningCount' | 'shoe'>): number { return state.runningCount / Math.max(state.shoe.length / 52, 0.25); }
export function seededRandom(seed: number): () => number {
  return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
}
/** Cards are dealt from the beginning of the array. Supply RNG for reproducible shoes. */
export function createShoe(decks: number = 6, random: () => number = Math.random): Card[] {
  const cards: Card[] = [];
  for (let i = 0; i < decks; i++) for (const suit of SUITS) for (const rank of RANKS) cards.push({ rank, suit });
  for (let i = cards.length - 1; i > 0; i--) { const j = Math.floor(random() * (i + 1)); [cards[i], cards[j]] = [cards[j], cards[i]]; }
  return cards;
}
export function createGame(options: { bankroll?: number; rules?: Partial<Rules>; shoe?: Card[]; seed?: number } = {}): GameState {
  const rules = { ...DEFAULT_RULES, ...options.rules };
  const seed = options.seed ?? Math.floor(Math.random() * 0x7fffffff);
  const shoe = options.shoe ? [...options.shoe] : createShoe(rules.decks, seededRandom(seed));
  return { rules, phase: 'betting', bankroll: options.bankroll ?? 1000, shoe, dealer: [], hands: [], activeHand: 0, runningCount: 0, holeRevealed: false, insuranceBet: 0, insurancePayout: 0, rounds: 0, history: [], message: 'Choose your bet and deal a hand.', seed, cutCard: Math.floor(shoe.length * 0.25) };
}
export interface StrategyOptions { canDouble?: boolean; canSplit?: boolean; canSurrender?: boolean; fromSplit?: boolean }
export interface StrategyAdvice { action: Move; reason: string }
/** Total-dependent basic strategy for US hole-card games, 4–8 decks. One/two deck deviations are not included. */
export function basicStrategy(cards: readonly Card[], dealerCard: Card, rules: Partial<Rules> = {}, options: StrategyOptions = {}): StrategyAdvice {
  const r = { ...DEFAULT_RULES, ...rules };
  const { total, soft } = score(cards);
  const up = cardValue(dealerCard);
  const canDouble = (options.canDouble ?? cards.length === 2) && (!options.fromSplit || r.doubleAfterSplit);
  const canSplit = (options.canSplit ?? true) && cards.length === 2 && cardValue(cards[0]) === cardValue(cards[1]);
  const canSurrender = (options.canSurrender ?? r.surrender) && r.surrender && cards.length === 2 && !options.fromSplit;
  const advice = (action: Move, detail: string): StrategyAdvice => ({ action, reason: detail });
  if (total >= 21) return advice('stand', 'You have 21. Stand and let the dealer finish.');
  if (canSplit) {
    const pair = cardValue(cards[0]);
    const split = pair === 11 || pair === 8 || (pair === 9 && [2,3,4,5,6,8,9].includes(up)) || (pair === 7 && up <= 7) || (pair === 6 && up <= 6 && (up >= 3 || r.doubleAfterSplit)) || ([2,3].includes(pair) && up <= 7 && (up >= 4 || r.doubleAfterSplit)) || (pair === 4 && r.doubleAfterSplit && [5,6].includes(up));
    // H17 late surrender changes 8,8 vs A; surrender is otherwise evaluated after pair splitting.
    if (pair === 8 && up === 11 && r.hitSoft17 && canSurrender) return advice('surrender', 'Against an ace in H17, surrender this pair of eights when allowed.');
    if (split) return advice('split', `Split your pair against the dealer’s ${dealerCard.rank}. Two hands have the better long-term expectation.`);
  }
  if (!soft && canSurrender && ((total === 16 && [9,10,11].includes(up)) || (total === 15 && (up === 10 || (r.hitSoft17 && up === 11))) || (total === 17 && r.hitSoft17 && up === 11))) return advice('surrender', 'Surrender returns half your bet and reduces the expected loss on this unfavorable hand.');
  if (soft) {
    let double = false;
    let fallback: Move = 'hit';
    if (total >= 20) fallback = 'stand';
    else if (total === 19) { double = r.hitSoft17 && up === 6; fallback = 'stand'; }
    else if (total === 18) { double = up >= (r.hitSoft17 ? 2 : 3) && up <= 6; fallback = up <= 8 ? 'stand' : 'hit'; }
    else if (total === 17) double = up >= 3 && up <= 6;
    else if (total === 15 || total === 16) double = up >= 4 && up <= 6;
    else if (total === 13 || total === 14) double = [5,6].includes(up);
    if (double && canDouble) return advice('double', `Double soft ${total} against ${dealerCard.rank}; the ace gives your hand flexibility.`);
    return advice(fallback, `${fallback === 'stand' ? 'Stand on' : 'Hit'} soft ${total} against the dealer’s ${dealerCard.rank}${double ? ' when doubling is unavailable' : ''}.`);
  }
  const shouldDouble = (total === 9 && up >= 3 && up <= 6) || (total === 10 && up <= 9) || (total === 11 && (up !== 11 || r.hitSoft17));
  if (shouldDouble && canDouble) return advice('double', `Double ${total} against ${dealerCard.rank} to increase your stake in a favorable situation.`);
  const stand = total >= 17 || (total >= 13 && up <= 6) || (total === 12 && up >= 4 && up <= 6);
  const action = stand ? 'stand' : 'hit';
  return advice(action, `${stand ? 'Stand on' : 'Hit'} hard ${total} against the dealer’s ${dealerCard.rank}.`);
}
export function availableActions(state: GameState): Move[] {
  if (state.phase !== 'playing') return [];
  const hand = state.hands[state.activeHand];
  if (!hand || hand.status !== 'playing') return [];
  const actions: Move[] = ['hit', 'stand'];
  if (hand.cards.length === 2 && state.bankroll >= hand.bet && (!hand.fromSplit || state.rules.doubleAfterSplit) && !hand.splitAces) actions.push('double');
  if (hand.cards.length === 2 && cardValue(hand.cards[0]) === cardValue(hand.cards[1]) && state.hands.length < 4 && state.bankroll >= hand.bet && !hand.splitAces) actions.push('split');
  if (state.rules.surrender && hand.cards.length === 2 && !hand.fromSplit) actions.push('surrender');
  return actions;
}
const money = (n: number) => Math.round(n * 100) / 100;
function clone(state: GameState): GameState { return { ...state, rules: { ...state.rules }, shoe: [...state.shoe], dealer: [...state.dealer], hands: state.hands.map(h => ({ ...h, cards: [...h.cards] })), history: [...state.history] }; }
function shuffle(state: GameState, cards?: Card[]) {
  state.seed = (state.seed + 1) >>> 0;
  state.shoe = cards ? [...cards] : createShoe(state.rules.decks, seededRandom(state.seed));
  state.cutCard = Math.floor(state.shoe.length * 0.25);
  state.runningCount = 0;
}
function draw(state: GameState, visible = true): Card {
  // A cut card normally prevents this; handle an exceptionally long split round safely.
  if (state.shoe.length === 0) shuffle(state);
  const card = state.shoe.shift()!;
  if (visible) state.runningCount += hiLo(card);
  return card;
}
function revealHole(state: GameState) {
  if (!state.holeRevealed && state.dealer[1]) { state.runningCount += hiLo(state.dealer[1]); state.holeRevealed = true; }
}
function settle(state: GameState) {
  revealHole(state);
  const dealer = score(state.dealer);
  const playDealer = !dealer.blackjack && state.hands.some(h => h.status !== 'bust' && h.status !== 'surrendered' && !(score(h.cards).blackjack && !h.fromSplit));
  if (playDealer) while (score(state.dealer).total < 17 || (state.rules.hitSoft17 && score(state.dealer).total === 17 && score(state.dealer).soft)) state.dealer.push(draw(state));
  const finalDealer = score(state.dealer);
  for (const hand of state.hands) {
    const player = score(hand.cards);
    let outcome: HandOutcome;
    let payout: number;
    if (hand.status === 'surrendered') { outcome = 'surrender'; payout = hand.bet / 2; }
    else if (player.bust) { outcome = 'loss'; payout = 0; }
    else if (player.blackjack && !hand.fromSplit) { outcome = finalDealer.blackjack ? 'push' : 'blackjack'; payout = finalDealer.blackjack ? hand.bet : hand.bet * (state.rules.blackjackPayout === '3:2' ? 2.5 : 2.2); }
    else if (finalDealer.blackjack) { outcome = 'loss'; payout = 0; }
    else if (finalDealer.bust || player.total > finalDealer.total) { outcome = 'win'; payout = hand.bet * 2; }
    else if (player.total === finalDealer.total) { outcome = 'push'; payout = hand.bet; }
    else { outcome = 'loss'; payout = 0; }
    hand.outcome = outcome;
    hand.payout = money(payout);
    if (hand.status === 'playing') hand.status = 'stood';
    state.bankroll = money(state.bankroll + hand.payout);
  }
  if (state.insuranceBet && finalDealer.blackjack) { state.insurancePayout = money(state.insuranceBet * 3); state.bankroll = money(state.bankroll + state.insurancePayout); }
  const bet = money(state.hands.reduce((sum, hand) => sum + hand.bet, 0) + state.insuranceBet);
  const returned = state.hands.reduce((sum, hand) => sum + (hand.payout ?? 0), 0) + state.insurancePayout;
  const profit = money(returned - bet);
  state.rounds++;
  state.history.push({ id: state.rounds, bet, profit, bankroll: state.bankroll, outcomes: state.hands.map(h => h.outcome!) });
  state.history = state.history.slice(-500);
  state.phase = 'settled';
  state.message = profit > 0 ? `You won ${money(profit)} credits.` : profit < 0 ? `You lost ${money(-profit)} credits.` : state.hands.every(hand => hand.outcome === 'push') && !state.insuranceBet ? 'Push. Your bet is returned.' : 'Round breaks even. No credits won or lost.';
}
function advance(state: GameState) {
  const next = state.hands.findIndex((hand, index) => index > state.activeHand && hand.status === 'playing');
  if (next !== -1) { state.activeHand = next; state.message = `Playing hand ${next + 1}.`; } else settle(state);
}
function afterPeek(state: GameState) {
  if (score(state.dealer).blackjack || score(state.hands[0].cards).blackjack) settle(state);
  else { state.phase = 'playing'; state.message = 'Your move.'; }
}
/** Pure reducer: shoe refresh uses state.seed, never ambient randomness. Invalid actions leave state intact. */
export function gameReducer(previous: GameState, action: GameAction): GameState {
  if (action.type === 'shuffle') {
    if (previous.phase === 'playing' || previous.phase === 'insurance') return previous;
    const state = clone(previous); shuffle(state, action.shoe); state.message = 'Fresh shoe. The count is reset.'; return state;
  }
  if (action.type === 'deal') {
    if (!['betting','settled'].includes(previous.phase) || !Number.isFinite(action.bet) || action.bet < 1 || action.bet > previous.bankroll) return previous;
    const state = clone(previous);
    if (state.shoe.length <= state.cutCard) shuffle(state);
    const bet = money(action.bet);
    state.bankroll = money(state.bankroll - bet);
    state.dealer = []; state.hands = []; state.activeHand = 0; state.holeRevealed = false; state.insuranceBet = 0; state.insurancePayout = 0;
    const first = draw(state); state.dealer.push(draw(state)); const second = draw(state); state.dealer.push(draw(state, false));
    state.hands = [{ cards: [first,second], bet, status: 'playing', fromSplit: false, splitAces: false }];
    if (state.dealer[0].rank === 'A') { state.phase = 'insurance'; state.message = 'Dealer shows an ace. Insurance costs half your bet and pays 2:1.'; }
    else afterPeek(state);
    return state;
  }
  if (action.type === 'insurance' || action.type === 'declineInsurance') {
    if (previous.phase !== 'insurance') return previous;
    const cost = money(previous.hands[0].bet / 2);
    if (action.type === 'insurance' && previous.bankroll < cost) return previous;
    const state = clone(previous);
    if (action.type === 'insurance') { state.insuranceBet = cost; state.bankroll = money(state.bankroll - cost); }
    afterPeek(state); return state;
  }
  if (!availableActions(previous).includes(action.type)) return previous;
  const state = clone(previous);
  const hand = state.hands[state.activeHand];
  if (action.type === 'hit') {
    hand.cards.push(draw(state));
    const value = score(hand.cards);
    if (value.bust || value.total === 21) { hand.status = value.bust ? 'bust' : 'stood'; advance(state); }
  } else if (action.type === 'stand') { hand.status = 'stood'; advance(state); }
  else if (action.type === 'surrender') { hand.status = 'surrendered'; advance(state); }
  else if (action.type === 'double') {
    state.bankroll = money(state.bankroll - hand.bet); hand.bet *= 2; hand.cards.push(draw(state)); hand.status = score(hand.cards).bust ? 'bust' : 'stood'; advance(state);
  } else if (action.type === 'split') {
    state.bankroll = money(state.bankroll - hand.bet);
    const splitAces = hand.cards[0].rank === 'A';
    const first: Hand = { cards: [hand.cards[0], draw(state)], bet: hand.bet, status: 'playing', fromSplit: true, splitAces };
    const second: Hand = { cards: [hand.cards[1], draw(state)], bet: hand.bet, status: 'playing', fromSplit: true, splitAces };
    for (const newHand of [first,second]) if (splitAces || score(newHand.cards).total === 21) newHand.status = 'stood';
    state.hands.splice(state.activeHand, 1, first, second);
    if (first.status !== 'playing') advance(state);
    else state.message = `Playing hand ${state.activeHand + 1} of ${state.hands.length}.`;
  }
  return state;
}
