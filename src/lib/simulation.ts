import { availableActions, basicStrategy, cardValue, createGame, DEFAULT_RULES, gameReducer, score } from './blackjack';
import type { Card, GameState, Move, Rules } from './blackjack';
import { validateSavedPractice } from './storage';

export type SimulationMode = 'guided' | 'test';
export type SimulationChoice = Move | 'insurance' | 'declineInsurance';
export type SimulationTopic = 'hard' | 'soft' | 'pairs' | 'insurance';
export interface SimulationConfiguration { rounds: 10 | 25 | 50; mode: SimulationMode; countChecks: boolean; rules: Rules }
export interface SimulationDecision {
  id: number; round: number; hand: number; cards: Card[]; dealer: Card;
  choices: SimulationChoice[]; chosen: SimulationChoice; recommended: SimulationChoice;
  explanation: string; correct: boolean; topic: SimulationTopic;
}
export interface SimulationCount { round: number; answer: number; expected: number; correct: boolean; shoeNumber: number }
export type SimulationStage = 'ready' | 'playing' | 'decisionFeedback' | 'roundReview' | 'countCheck' | 'countFeedback' | 'complete';
export type SimulationEvent = { type: 'deal' | 'continueDecision' | 'checkCount' } | { type: 'play'; choice: SimulationChoice } | { type: 'count'; answer: number } | { type: 'finishRound'; at: string };
export interface SimulationSession {
  version: 1; id: string; createdAt: string; completedAt: string | null; initialSeed: number;
  configuration: SimulationConfiguration; game: GameState; stage: SimulationStage;
  completedRounds: number; decisions: SimulationDecision[]; counts: SimulationCount[];
  shoeNumber: number; roundStartedNewShoe: boolean; countResetDuringRound: boolean; events: SimulationEvent[];
}
export interface SimulationStore { version: 1; active: SimulationSession | null; history: SimulationSession[] }
export const SIMULATION_STORAGE_KEY = 'blackjack-studio:simulation:v1';
export const simulationChoiceLabels: Record<SimulationChoice, string> = { hit:'Hit', stand:'Stand', double:'Double', split:'Split', surrender:'Surrender', insurance:'Take insurance', declineInsurance:'No insurance' };
export const simulationTopicLabels: Record<SimulationTopic, string> = { hard:'Hard totals', soft:'Soft hands', pairs:'Pairs', insurance:'Insurance' };
const stages: SimulationStage[] = ['ready','playing','decisionFeedback','roundReview','countCheck','countFeedback','complete'];
const object = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value);
const validDate = (value: unknown): value is string => typeof value === 'string' && value.length <= 30 && Number.isFinite(Date.parse(value));
function validConfiguration(value: unknown): value is SimulationConfiguration {
  if (!object(value) || ![10,25,50].includes(value.rounds as number) || !['guided','test'].includes(value.mode as string) || typeof value.countChecks !== 'boolean' || !object(value.rules)) return false;
  const r = value.rules;
  return [4,6,8].includes(r.decks as number) && ['3:2','6:5'].includes(r.blackjackPayout as string) && ['hitSoft17','doubleAfterSplit','surrender'].every(key => typeof r[key] === 'boolean');
}
export function createSimulation(configuration: Partial<SimulationConfiguration> = {}, options: { seed?: number; id?: string; createdAt?: string } = {}): SimulationSession {
  const config: SimulationConfiguration = { rounds: [10,25,50].includes(configuration.rounds ?? 0) ? configuration.rounds! : 10, mode: configuration.mode === 'test' ? 'test' : 'guided', countChecks: configuration.countChecks !== false, rules: { ...DEFAULT_RULES, ...configuration.rules } };
  if (!validConfiguration(config as unknown)) config.rules = { ...DEFAULT_RULES };
  const initialSeed = typeof options.seed === 'number' && Number.isInteger(options.seed) && options.seed >= 0 && options.seed <= 0xffffffff ? options.seed : Math.floor(Math.random() * 0x7fffffff);
  const game = createGame({ seed:initialSeed, bankroll:1000, rules:config.rules });
  game.cutCard = Math.max(64, game.cutCard);
  return { version:1, id:options.id ?? crypto.randomUUID(), createdAt:options.createdAt ?? new Date().toISOString(), completedAt:null, initialSeed, configuration:config, game, stage:'ready', completedRounds:0, decisions:[], counts:[], shoeNumber:1, roundStartedNewShoe:true, countResetDuringRound:false, events:[] };
}
export function simulationChoices(session: SimulationSession): SimulationChoice[] {
  if (session.stage !== 'playing') return [];
  return session.game.phase === 'insurance' ? ['declineInsurance','insurance'] : availableActions(session.game);
}
/** Only first attempts are scored. Feedback and recall gates must finish before another round is dealt. */
export function simulationReducer(previous: SimulationSession, event: SimulationEvent): SimulationSession {
  if (previous.stage === 'complete') return previous;
  let next = { ...previous };
  const game = previous.game;
  switch (event.type) {
    case 'deal': {
      if (previous.stage !== 'ready' || previous.completedRounds >= previous.configuration.rounds) return previous;
      const dealt = gameReducer(game, { type:'deal', bet:1 });
      if (dealt === game) return previous;
      dealt.cutCard = Math.max(64, dealt.cutCard);
      const shuffled = dealt.seed !== game.seed;
      next = { ...next, game:dealt, stage:dealt.phase === 'settled' ? 'roundReview' : 'playing', shoeNumber:previous.shoeNumber + Number(shuffled), roundStartedNewShoe:previous.completedRounds === 0 || shuffled, countResetDuringRound:false };
      break;
    }
    case 'play': {
      const choices = simulationChoices(previous);
      if (!choices.includes(event.choice)) return previous;
      const hand = game.hands[game.activeHand];
      const advice = game.phase === 'insurance' ? { action:'declineInsurance' as const, reason:'Basic strategy declines insurance. It is a separate side bet, not protection for your main hand.' } : basicStrategy(hand.cards, game.dealer[0], game.rules, { canDouble:choices.includes('double'), canSplit:choices.includes('split'), canSurrender:choices.includes('surrender'), fromSplit:hand.fromSplit });
      const played = gameReducer(game, { type:event.choice });
      if (played === game) return previous;
      played.cutCard = Math.max(64, played.cutCard);
      const decision: SimulationDecision = { id:previous.decisions.length, round:previous.completedRounds + 1, hand:game.activeHand + 1, cards:[...hand.cards], dealer:game.dealer[0], choices, chosen:event.choice, recommended:advice.action, explanation:advice.reason, correct:event.choice === advice.action, topic:game.phase === 'insurance' ? 'insurance' : hand.cards.length === 2 && cardValue(hand.cards[0]) === cardValue(hand.cards[1]) ? 'pairs' : score(hand.cards).soft ? 'soft' : 'hard' };
      next = { ...next, game:played, decisions:[...previous.decisions, decision], shoeNumber:previous.shoeNumber + Number(played.seed !== game.seed), countResetDuringRound:previous.countResetDuringRound || played.seed !== game.seed, stage:previous.configuration.mode === 'guided' ? 'decisionFeedback' : played.phase === 'settled' ? 'roundReview' : 'playing' };
      break;
    }
    case 'continueDecision':
      if (previous.stage !== 'decisionFeedback') return previous;
      next.stage = game.phase === 'settled' ? 'roundReview' : 'playing';
      break;
    case 'checkCount':
      if (previous.stage !== 'roundReview' || !previous.configuration.countChecks || previous.countResetDuringRound) return previous;
      next.stage = 'countCheck';
      break;
    case 'count':
      if (previous.stage !== 'countCheck' || !Number.isInteger(event.answer) || Math.abs(event.answer) > 416) return previous;
      next.counts = [...previous.counts, { round:previous.completedRounds + 1, answer:event.answer, expected:game.runningCount, correct:event.answer === game.runningCount, shoeNumber:previous.shoeNumber }];
      next.stage = 'countFeedback';
      break;
    case 'finishRound':
      if (!validDate(event.at) || !(previous.stage === 'countFeedback' || previous.stage === 'roundReview' && (!previous.configuration.countChecks || previous.countResetDuringRound))) return previous;
      next.completedRounds += 1;
      next.stage = next.completedRounds === previous.configuration.rounds ? 'complete' : 'ready';
      if (next.stage === 'complete') next.completedAt = event.at;
      break;
    default: return previous;
  }
  next.events = [...previous.events, event];
  return next;
}
export function simulationAccuracy(items: readonly { correct:boolean }[]): number | null { return items.length ? Math.round(items.filter(item => item.correct).length / items.length * 100) : null; }
export function simulationFocus(session: SimulationSession): { title:string; detail:string; target:'counting' | 'strategy' | 'repeat' } {
  const countAccuracy = simulationAccuracy(session.counts);
  const strategyAccuracy = simulationAccuracy(session.decisions);
  if (countAccuracy !== null && countAccuracy < 90 && (strategyAccuracy === null || countAccuracy <= strategyAccuracy)) return { title:'Practice the running count', detail:'Keep one total through the shoe. Reset it only when a new shoe starts.', target:'counting' };
  const wrong = session.decisions.filter(item => !item.correct);
  if (wrong.length) {
    const frequencies = wrong.reduce<Partial<Record<SimulationTopic,number>>>((all,item) => ({ ...all, [item.topic]:(all[item.topic] ?? 0)+1 }), {});
    const topic = Object.entries(frequencies).sort((a,b) => b[1] - a[1])[0][0] as SimulationTopic;
    return { title:`Review ${simulationTopicLabels[topic].toLowerCase()}`, detail:'Retry the missed decisions below, then use the strategy guide before another session.', target:'strategy' };
  }
  return { title:session.configuration.mode === 'guided' ? 'Try a test session' : 'Repeat to check consistency', detail:session.decisions.length ? 'A new shoe tests the same skill with different hands.' : 'No strategy decisions occurred. Start another session for a useful assessment.', target:'repeat' };
}
/** Reconstruct the session from a bounded action log. Persisted scores, cards and stage cannot disagree with their first attempts. */
export function validateSimulation(value: unknown): value is SimulationSession {
  if (!object(value) || value.version !== 1 || typeof value.id !== 'string' || !value.id.length || value.id.length > 100 || !validDate(value.createdAt) || !validConfiguration(value.configuration) || !Number.isInteger(value.initialSeed) || (value.initialSeed as number) < 0 || (value.initialSeed as number) > 0xffffffff || !stages.includes(value.stage as SimulationStage) || !Array.isArray(value.events) || value.events.length > 5000) return false;
  try {
    let replay = createSimulation(value.configuration, { id:value.id, createdAt:value.createdAt, seed:value.initialSeed as number });
    for (const event of value.events) {
      if (!object(event) || typeof event.type !== 'string') return false;
      const next = simulationReducer(replay, event as SimulationEvent);
      if (next === replay) return false;
      replay = next;
    }
    if (!validateSavedPractice({ version:1, game:replay.game, stats:{ decisions:0, correct:0, drills:0, correctDrills:0 }, showHints:false, showCount:false, bet:1 })) return false;
    return JSON.stringify(replay) === JSON.stringify(value);
  } catch { return false; }
}
export function loadSimulationStore(raw: string | null): SimulationStore {
  const fresh: SimulationStore = { version:1, active:null, history:[] };
  if (!raw || raw.length > 12_000_000) return fresh;
  try {
    const data: unknown = JSON.parse(raw);
    if (!object(data) || data.version !== 1 || !Array.isArray(data.history) || data.history.length > 20) return fresh;
    const history = data.history.filter((item): item is SimulationSession => validateSimulation(item) && item.stage === 'complete');
    return { version:1, active:validateSimulation(data.active) ? data.active : null, history:history.filter((item,index) => history.findIndex(other => other.id === item.id) === index) };
  } catch { return fresh; }
}
