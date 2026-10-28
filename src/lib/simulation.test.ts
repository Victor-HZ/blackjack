import { describe, expect, it } from 'vitest';
import { basicStrategy, createGame, hiLo } from './blackjack';
import type { Card, Rank } from './blackjack';
import { createSimulation, loadSimulationStore, simulationAccuracy, simulationChoices, simulationFocus, simulationReducer, validateSimulation } from './simulation';
import type { SimulationConfiguration, SimulationSession } from './simulation';

const date = '2026-10-28T12:00:00.000Z';
function fresh(configuration: Partial<SimulationConfiguration> = {}, seed = 19): SimulationSession { return createSimulation(configuration, { seed, id:'test-session', createdAt:date }); }
function step(session: SimulationSession): SimulationSession {
  switch (session.stage) {
    case 'ready': return simulationReducer(session, { type:'deal' });
    case 'playing': {
      const choices = simulationChoices(session);
      const hand = session.game.hands[session.game.activeHand];
      const choice = session.game.phase === 'insurance' ? 'declineInsurance' : basicStrategy(hand.cards, session.game.dealer[0], session.game.rules, { canDouble:choices.includes('double'), canSplit:choices.includes('split'), canSurrender:choices.includes('surrender'), fromSplit:hand.fromSplit }).action;
      return simulationReducer(session, { type:'play', choice });
    }
    case 'decisionFeedback': return simulationReducer(session, { type:'continueDecision' });
    case 'roundReview': return simulationReducer(session, session.configuration.countChecks && !session.countResetDuringRound ? { type:'checkCount' } : { type:'finishRound', at:date });
    case 'countCheck': return simulationReducer(session, { type:'count', answer:session.game.runningCount });
    case 'countFeedback': return simulationReducer(session, { type:'finishRound', at:date });
    case 'complete': return session;
  }
}
function complete(session: SimulationSession): SimulationSession {
  for (let n=0; n<5000 && session.stage !== 'complete'; n++) { const next = step(session); expect(next).not.toBe(session); session = next; }
  expect(session.stage).toBe('complete');
  return session;
}
function customGame(ranks: Rank[]): SimulationSession {
  const session = fresh({ mode:'test', countChecks:false });
  const shoe: Card[] = [...ranks.map(rank => ({ rank, suit:'♣' as const })), ...Array.from({length:50}, () => ({rank:'10' as const,suit:'♠' as const}))];
  return { ...session, game:createGame({ shoe, seed:19 }) };
}

describe('fixed-round simulation', () => {
  it.each([10,25,50] as const)('finishes exactly %i rounds, counts first answers and cannot deal past the limit', rounds => {
    const result = complete(fresh({ rounds, mode:'test' }));
    expect(result.completedRounds).toBe(rounds);
    expect(result.game.rounds).toBe(rounds);
    expect(result.counts).toHaveLength(rounds);
    expect(simulationAccuracy(result.decisions)).toBe(100);
    expect(simulationAccuracy(result.counts)).toBe(100);
    expect(simulationReducer(result, {type:'deal'})).toBe(result);
    expect(validateSimulation(JSON.parse(JSON.stringify(result)))).toBe(true);
  });
  it('pauses guided decisions before accepting the next move or round', () => {
    let session = fresh();
    session = simulationReducer(session, {type:'deal'});
    expect(session.stage).toBe('playing');
    session = simulationReducer(session, {type:'play',choice:'hit'});
    expect(session.stage).toBe('decisionFeedback');
    expect(session.decisions).toHaveLength(1);
    expect(simulationReducer(session,{type:'play',choice:'stand'})).toBe(session);
    expect(simulationReducer(session,{type:'deal'})).toBe(session);
    session = simulationReducer(session,{type:'continueDecision'});
    expect(['playing','roundReview']).toContain(session.stage);
  });
  it('ignores illegal and out-of-order actions without adding scores', () => {
    const session = fresh();
    expect(simulationReducer(session,{type:'play',choice:'stand'})).toBe(session);
    expect(simulationReducer(session,{type:'count',answer:0})).toBe(session);
    expect(simulationReducer(session,{type:'finishRound',at:date})).toBe(session);
    const playing = simulationReducer(session,{type:'deal'});
    expect(simulationReducer(playing,{type:'play',choice:'insurance'})).toBe(playing);
    expect(playing.decisions).toHaveLength(0);
  });
  it('counts a natural as one round without inventing a strategy decision', () => {
    let session = simulationReducer(customGame(['A','9','K','8']),{type:'deal'});
    expect(session.stage).toBe('roundReview');
    expect(session.decisions).toHaveLength(0);
    session = simulationReducer(session,{type:'finishRound',at:date});
    expect(session.completedRounds).toBe(1);
    expect(simulationAccuracy(session.decisions)).toBeNull();
  });
  it('treats split hands as one round and records separate actual moves', () => {
    let session = simulationReducer(customGame(['8','6','8','10','3','2','10','10','5']),{type:'deal'});
    session = simulationReducer(session,{type:'play',choice:'split'});
    expect(session.game.hands).toHaveLength(2);
    expect(session.completedRounds).toBe(0);
    session = simulationReducer(session,{type:'play',choice:'stand'});
    expect(session.stage).toBe('playing');
    session = simulationReducer(session,{type:'play',choice:'stand'});
    expect(session.stage).toBe('roundReview');
    expect(session.game.rounds).toBe(1);
    expect(session.decisions.map(item=>item.hand)).toEqual([1,1,2]);
    expect(session.decisions[0].recommended).toBe('split');
  });
  it('grades insurance against basic strategy while preserving the normal hand', () => {
    let session = simulationReducer(customGame(['10','A','7','6','10']),{type:'deal'});
    expect(session.game.phase).toBe('insurance');
    session = simulationReducer(session,{type:'play',choice:'insurance'});
    expect(session.decisions[0]).toMatchObject({chosen:'insurance',recommended:'declineInsurance',correct:false,topic:'insurance'});
    expect(session.game.phase).toBe('playing');
    expect(simulationFocus(session).target).toBe('strategy');
  });
  it('keeps the hole card out of the running count until revealed', () => {
    const playing = simulationReducer(customGame(['4','6','5','10','10']),{type:'deal'});
    expect(playing.game.holeRevealed).toBe(false);
    expect(playing.game.runningCount).toBe(3);
    const settled = simulationReducer(playing,{type:'play',choice:'stand'});
    expect(settled.game.holeRevealed).toBe(true);
    expect(settled.game.runningCount).toBe([...settled.game.dealer,...settled.game.hands.flatMap(hand=>hand.cards)].reduce((sum,card)=>sum+hiLo(card),0));
  });
  it('requires a single valid count before advancing and preserves a wrong first answer', () => {
    let session = fresh({mode:'test'});
    while (session.stage !== 'roundReview') session=step(session);
    expect(simulationReducer(session,{type:'finishRound',at:date})).toBe(session);
    session=simulationReducer(session,{type:'checkCount'});
    expect(simulationReducer(session,{type:'count',answer:NaN})).toBe(session);
    expect(simulationReducer(session,{type:'count',answer:1.5})).toBe(session);
    const expected=session.game.runningCount;
    session=simulationReducer(session,{type:'count',answer:expected+1});
    expect(session.counts[0]).toMatchObject({answer:expected+1,expected,correct:false});
    expect(simulationReducer(session,{type:'count',answer:expected})).toBe(session);
    expect(simulationReducer(session,{type:'deal'})).toBe(session);
    session=simulationReducer(session,{type:'finishRound',at:date});
    expect(session.completedRounds).toBe(1);
    expect(simulationFocus(session).target).toBe('counting');
  });
  it('announces automatic shoe resets and never combines counts across shoes', () => {
    let session=fresh({rounds:50,mode:'test'});
    let resetSeen=false;
    while(session.stage!=='complete') {
      const before=session; session=step(session);
      if(before.game.seed!==session.game.seed) {
        resetSeen=true;
        expect(session.shoeNumber).toBe(before.shoeNumber+1);
        expect(session.roundStartedNewShoe).toBe(true);
        const visible=[...session.game.dealer.filter((_,i)=>i!==1||session.game.holeRevealed),...session.game.hands.flatMap(hand=>hand.cards)];
        expect(session.game.runningCount).toBe(visible.reduce((sum,card)=>sum+hiLo(card),0));
      }
    }
    expect(resetSeen).toBe(true);
  });
  it('excludes recall when an exceptional hand exhausts the shoe mid-round', () => {
    let session = fresh({mode:'test'});
    session = { ...session, game:createGame({shoe:[{rank:'2',suit:'♣'},{rank:'6',suit:'♠'},{rank:'3',suit:'♣'},{rank:'10',suit:'♣'}],seed:19}) };
    session = simulationReducer(session,{type:'deal'});
    session = simulationReducer(session,{type:'play',choice:'hit'});
    expect(session.countResetDuringRound).toBe(true);
    expect(session.shoeNumber).toBe(2);
    while(session.stage==='playing') session=simulationReducer(session,{type:'play',choice:'stand'});
    expect(session.stage).toBe('roundReview');
    expect(simulationReducer(session,{type:'checkCount'})).toBe(session);
    session=simulationReducer(session,{type:'finishRound',at:date});
    expect(session.completedRounds).toBe(1);
    expect(session.counts).toHaveLength(0);
  });
  it('normalizes invalid setup and keeps deterministic seeds reproducible', () => {
    expect(createSimulation({rounds:9 as 10,mode:'bogus' as 'test',rules:{...fresh().configuration.rules,decks:1}}).configuration).toMatchObject({rounds:10,mode:'guided',rules:{decks:6}});
    expect(complete(fresh({mode:'test',countChecks:false}))).toEqual(complete(fresh({mode:'test',countChecks:false})));
  });
  it('restores valid active sessions, rejects forged scores/stages/events, and keeps sound history', () => {
    let session=fresh(); session=step(step(session));
    const saved=JSON.parse(JSON.stringify(session));
    expect(validateSimulation(saved)).toBe(true);
    saved.decisions[0].correct=!saved.decisions[0].correct;
    expect(validateSimulation(saved)).toBe(false);
    expect(validateSimulation({...session,stage:'complete'})).toBe(false);
    expect(validateSimulation({...session,events:[...session.events,{type:'count',answer:0}]})).toBe(false);
    const finished=complete(fresh({mode:'test',countChecks:false}));
    const restored=loadSimulationStore(JSON.stringify({version:1,active:saved,history:[finished,finished]}));
    expect(restored.active).toBeNull(); expect(restored.history).toHaveLength(1);
    expect(loadSimulationStore('{')).toEqual({version:1,active:null,history:[]});
  });
});
