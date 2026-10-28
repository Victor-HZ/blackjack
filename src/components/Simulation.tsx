import { useEffect, useRef, useState } from 'react';
import { ArrowRight, Check, ChevronLeft, RotateCcw, Spade, X } from 'lucide-react';
import type { Card, Rules } from '../lib/blackjack';
import { score } from '../lib/blackjack';
import { createSimulation, loadSimulationStore, SIMULATION_STORAGE_KEY, simulationAccuracy, simulationChoiceLabels, simulationChoices, simulationFocus, simulationReducer } from '../lib/simulation';
import type { SimulationChoice, SimulationConfiguration, SimulationDecision, SimulationEvent, SimulationSession, SimulationStore } from '../lib/simulation';
import './Simulation.css';

const signed = (number: number) => number > 0 ? `+${number}` : String(number).replace('-', '−');
const percentage = (number: number | null) => number === null ? '—' : `${number}%`;
function initialStore(): SimulationStore {
  try { return loadSimulationStore(localStorage.getItem(SIMULATION_STORAGE_KEY)); }
  catch { return { version:1, active:null, history:[] }; }
}
function CardFace({ card, hidden = false }: { card: Card; hidden?: boolean }) {
  if (hidden) return <div className="sim-card sim-card-back" role="img" aria-label="Face-down card"><Spade size={25}/></div>;
  const suit = { '♠':'spades', '♥':'hearts', '♣':'clubs', '♦':'diamonds' }[card.suit];
  return <div className={`sim-card ${['♥','♦'].includes(card.suit) ? 'sim-red' : ''}`} role="img" aria-label={`${card.rank} of ${suit}`}><span>{card.rank}<small>{card.suit}</small></span><b aria-hidden="true">{card.suit}</b></div>;
}
function HandCards({ cards }: { cards: Card[] }) { return <div className="sim-cards">{cards.map((card,index) => <CardFace key={index} card={card}/>)}</div>; }
function DecisionReview({ decision }: { decision: SimulationDecision }) {
  const [answer, setAnswer] = useState<SimulationChoice | null>(null);
  const reviewRef = useRef<HTMLElement>(null);
  const hadAnswer = useRef(false);
  useEffect(() => {
    if (answer !== null) {
      hadAnswer.current = true;
      reviewRef.current?.querySelector<HTMLElement>('.sim-feedback')?.focus({ preventScroll:true });
    } else if (hadAnswer.current) {
      reviewRef.current?.querySelector<HTMLButtonElement>('.sim-actions button')?.focus({ preventScroll:true });
    }
  }, [answer]);
  return <section ref={reviewRef} className="sim-panel sim-review" aria-label="Retry a missed decision">
    <div className="sim-row"><h3 tabIndex={-1}>Round {decision.round} · Hand {decision.hand}</h3><span>First attempt: {simulationChoiceLabels[decision.chosen]}</span></div>
    <div className="sim-review-cards"><div><p>Your hand</p><HandCards cards={decision.cards}/></div><div><p>Dealer’s upcard</p><HandCards cards={[decision.dealer]}/></div></div>
    <p className="sim-question">What would you play now?</p>
    <div className="sim-actions">{decision.choices.map(choice => <button key={choice} disabled={answer !== null} onClick={() => setAnswer(choice)} className="sim-button">{simulationChoiceLabels[choice]}</button>)}</div>
    {answer !== null && <div className="sim-feedback" role="status" tabIndex={-1}><strong>{answer === decision.recommended ? 'Correct' : `Recommended: ${simulationChoiceLabels[decision.recommended]}`}</strong><p>{decision.explanation}</p><small>Review answers do not change your session score.</small>{answer !== decision.recommended && <button className="sim-button" onClick={() => setAnswer(null)}>Try this decision again</button>}</div>}
  </section>;
}
function Results({ session, onRepeat, onPractice, onBack }: { session: SimulationSession; onRepeat: (mode?: SimulationConfiguration['mode']) => void; onPractice: (target:'counting' | 'strategy', rules?: Rules) => void; onBack: () => void }) {
  const [reviewIndex, setReviewIndex] = useState(0);
  const mistakes = session.decisions.filter(item => !item.correct);
  const countMistakes = session.counts.filter(item => !item.correct);
  const focus = simulationFocus(session);
  return <div className="sim-results" data-testid="simulation-results">
    <div className="sim-result-heading"><Check size={25}/><div><h2 tabIndex={-1}>Session complete</h2><p>{session.completedRounds} rounds · {session.configuration.mode === 'guided' ? 'Guided' : 'Test'}</p></div></div>
    <div className="sim-metrics"><div><strong>{percentage(simulationAccuracy(session.decisions))}</strong><span>Strategy accuracy</span><small>{session.decisions.filter(item => item.correct).length} of {session.decisions.length} decisions</small></div><div><strong>{percentage(simulationAccuracy(session.counts))}</strong><span>Count accuracy</span><small>{session.counts.length ? `${session.counts.filter(item => item.correct).length} of ${session.counts.length} checks` : 'Count checks off'}</small></div></div>
    <p className="sim-muted">{session.configuration.rules.decks} decks · {session.configuration.rules.hitSoft17 ? 'H17' : 'S17'} · {session.configuration.rules.blackjackPayout} blackjack. Scores measure first-attempt decisions and counts. Winning a hand does not raise your skill score.</p>
    <section className="sim-panel"><h3 tabIndex={-1}>{focus.title}</h3><p>{focus.detail}</p><button className="sim-primary" onClick={() => focus.target === 'repeat' ? onRepeat(session.configuration.mode === 'guided' ? 'test' : undefined) : onPractice(focus.target, session.configuration.rules)}>{focus.target === 'counting' ? 'Practice card counting' : focus.target === 'strategy' ? 'Open strategy guide' : session.configuration.mode === 'guided' ? 'Start a test session' : 'Start another session'}<ArrowRight size={17}/></button></section>
    {mistakes.length > 0 && <section><div className="sim-section-heading"><h3 tabIndex={-1}>Retry missed decisions</h3><span>{reviewIndex + 1} of {mistakes.length}</span></div><DecisionReview key={mistakes[reviewIndex].id} decision={mistakes[reviewIndex]}/>{mistakes.length > 1 && <div className="sim-review-navigation"><button className="sim-button" disabled={reviewIndex === 0} onClick={() => setReviewIndex(index => index - 1)}>Previous mistake</button><button className="sim-button" disabled={reviewIndex === mistakes.length - 1} onClick={() => setReviewIndex(index => index + 1)}>Next mistake</button></div>}</section>}
    {countMistakes.length > 0 && <section className="sim-panel"><h3 tabIndex={-1}>Count review</h3><div className="sim-count-review">{countMistakes.map(item => <div key={item.round}><span>Round {item.round} · Shoe {item.shoeNumber}</span><span>Your count {signed(item.answer)}</span><strong>Correct {signed(item.expected)}</strong></div>)}</div><p>2–6: +1 · 7–9: 0 · 10–A: −1. Reset at a new shoe.</p></section>}
    <div className="sim-actions"><button className="sim-button" onClick={() => onRepeat()}><RotateCcw size={16}/>Repeat {session.configuration.rounds} rounds</button><button className="sim-button" onClick={onBack}>Back to setup</button></div>
  </div>;
}

export function Simulation({ rules, onPractice, onExit }: { rules: Rules; onPractice: (target:'counting' | 'strategy', rules?: Rules) => void; onExit: () => void }) {
  const [store, setStore] = useState(initialStore);
  const sectionRef = useRef<HTMLElement>(null);
  const endButtonRef = useRef<HTMLButtonElement>(null);
  const keepButtonRef = useRef<HTMLButtonElement>(null);
  const wasConfirming = useRef(false);
  const [rounds, setRounds] = useState<SimulationConfiguration['rounds']>(10);
  const [mode, setMode] = useState<SimulationConfiguration['mode']>('guided');
  const [countChecks, setCountChecks] = useState(true);
  const [countAnswer, setCountAnswer] = useState('');
  const [storageError, setStorageError] = useState(false);
  const [confirmEnd, setConfirmEnd] = useState(false);
  const [historyID, setHistoryID] = useState<string | null>(null);
  const session = historyID ? store.history.find(item => item.id === historyID) ?? null : store.active;
  useEffect(() => {
    if (confirmEnd) {
      wasConfirming.current = true;
      keepButtonRef.current?.focus();
      return;
    }
    if (wasConfirming.current) {
      wasConfirming.current = false;
      if (endButtonRef.current) { endButtonRef.current.focus({ preventScroll:true }); return; }
    }
    const heading = sectionRef.current?.querySelector<HTMLElement>(session?.stage === 'complete' ? '.sim-result-heading h2' : '.sim-panel h3, .sim-setup h2');
    heading?.focus({ preventScroll:true });
    heading?.scrollIntoView({ block:'nearest', behavior:'auto' });
  }, [session?.stage, session?.id, confirmEnd]);
  useEffect(() => {
    try { localStorage.setItem(SIMULATION_STORAGE_KEY, JSON.stringify(store)); setStorageError(false); }
    catch { setStorageError(true); }
  }, [store]);
  function start(configuration: SimulationConfiguration) {
    setStore(previous => ({ ...previous, active:createSimulation(configuration) }));
    setHistoryID(null); setCountAnswer(''); setConfirmEnd(false);
  }
  function dispatch(event: SimulationEvent) {
    setStore(previous => {
      if (!previous.active) return previous;
      const active = simulationReducer(previous.active, event);
      if (active === previous.active) return previous;
      const history = active.stage === 'complete' ? [...previous.history.filter(item => item.id !== active.id), active].slice(-20) : previous.history;
      return { ...previous, active, history };
    });
  }
  const game = session?.game;
  const lastDecision = session?.decisions.at(-1);
  const lastCount = session?.counts.at(-1);
  const isTest = session?.configuration.mode === 'test';
  const parsedCount = /^[+-]?\d+$/.test(countAnswer.trim()) ? Number(countAnswer) : NaN;
  const validCount = Number.isInteger(parsedCount) && Math.abs(parsedCount) <= 416;
  const finishRound = () => { dispatch({ type:'finishRound', at:new Date().toISOString() }); setCountAnswer(''); };
  return <section ref={sectionRef} className="simulation" data-testid="simulation" aria-label="Blackjack simulation">
    {storageError && <p className="sim-notice" role="alert">This browser could not save your simulation. Keep this page open to finish.</p>}
    {!session ? <>
      <div className="sim-setup sim-panel"><h2 tabIndex={-1}>Set up a simulation</h2><p>Play a set number of rounds, then review your decisions.</p>
        <fieldset><legend>Rounds</legend><div className="sim-segmented">{([10,25,50] as const).map(value => <label key={value}><input type="radio" name="simulation-rounds" checked={rounds === value} onChange={() => setRounds(value)}/><span>{value} rounds</span></label>)}</div></fieldset>
        <fieldset><legend>Feedback</legend><div className="sim-mode-options">{(['guided','test'] as const).map(value => <label key={value}><input type="radio" name="simulation-mode" checked={mode === value} onChange={() => setMode(value)}/><span><strong>{value === 'guided' ? 'Guided' : 'Test'}</strong><small>{value === 'guided' ? 'Review each decision after you play.' : 'Keep feedback hidden until the end.'}</small></span></label>)}</div></fieldset>
        <label className="sim-checkbox"><input type="checkbox" checked={countChecks} onChange={event => setCountChecks(event.target.checked)}/><span>Check running count after each round</span></label>
        <p className="sim-rules">{rules.decks} decks · {rules.hitSoft17 ? 'Dealer hits soft 17' : 'Dealer stands on soft 17'} · {rules.blackjackPayout} blackjack. Fixed 1-point stakes.</p>
        <button className="sim-primary" onClick={() => start({ rounds, mode, countChecks, rules:{ ...rules } })}>Start simulation<ArrowRight size={17}/></button>
      </div>
      {store.history.length > 0 && <section className="sim-panel"><h3 tabIndex={-1}>Completed simulations</h3><div className="sim-history">{store.history.slice().reverse().map(item => <button key={item.id} onClick={() => setHistoryID(item.id)}><span><strong>{item.completedRounds} rounds · {item.configuration.mode === 'guided' ? 'Guided' : 'Test'}</strong><small>{new Date(item.completedAt!).toLocaleDateString()}</small></span><span>{percentage(simulationAccuracy(item.decisions))}<ArrowRight size={15}/></span></button>)}</div></section>}
    </> : session.stage === 'complete' ? <Results key={session.id} session={session} onPractice={onPractice} onRepeat={repeatMode => start({ ...session.configuration, mode:repeatMode ?? session.configuration.mode })} onBack={() => { setHistoryID(null); if (store.active?.stage === 'complete') setStore(previous => ({ ...previous, active:null })); }}/>: game && <>
      <div className="sim-session-header"><div><span>{isTest ? 'Test' : 'Guided'} · {session.configuration.rounds} rounds</span><h2 data-testid="simulation-round">Round {session.completedRounds + 1} of {session.configuration.rounds}</h2></div><button className="sim-text-button" onClick={onExit}><ChevronLeft size={16}/>Save & leave</button></div>
      <progress value={session.completedRounds} max={session.configuration.rounds} aria-label="Completed rounds"/>
      {session.stage === 'ready' ? <section className="sim-panel sim-ready"><Spade size={30}/><h3 tabIndex={-1}>{session.completedRounds ? 'Next round' : 'Ready to play'}</h3><p>{session.completedRounds ? 'Continue with the same running count unless a new shoe starts.' : 'Start the running count at zero. No advice appears before you choose a move.'}</p><button className="sim-primary" data-testid="simulation-deal" onClick={() => dispatch({ type:'deal' })}>{session.completedRounds ? 'Deal next round' : 'Deal first round'}<ArrowRight size={17}/></button></section> : <>
        {session.countResetDuringRound && <p className="sim-shoe-notice" role="status">A new shoe was needed during this hand. This round’s count check is skipped.</p>}
        {session.roundStartedNewShoe && !session.countResetDuringRound && <p className="sim-shoe-notice" role="status">Shoe {session.shoeNumber} · New shoe this round. Start from zero.</p>}
        {session.stage !== 'countCheck' && session.stage !== 'countFeedback' && <section className="sim-felt" aria-label="Simulation table"><div className="sim-felt-meta"><span>{game.rules.decks} decks · {game.rules.hitSoft17 ? 'H17' : 'S17'}</span><span>Shoe {session.shoeNumber}</span></div><div className="sim-dealer"><p>Dealer · {score(game.holeRevealed ? game.dealer : game.dealer.slice(0,1)).total}{!game.holeRevealed && ' + ?'}</p><div className="sim-cards">{game.dealer.map((card,index) => <CardFace key={index} card={card} hidden={index === 1 && !game.holeRevealed}/>)}</div></div><div className="sim-player-hands">{game.hands.map((hand,index) => <div key={index} className={game.phase === 'playing' && index === game.activeHand ? 'sim-active-hand' : ''}><p>{game.hands.length > 1 ? `Hand ${index + 1}` : 'Your hand'} · {score(hand.cards).total}{score(hand.cards).soft && ' soft'}{game.phase === 'playing' && index === game.activeHand ? ' · Your turn' : ''}</p><HandCards cards={hand.cards}/>{hand.outcome && <span className="sim-outcome">{hand.outcome}</span>}</div>)}</div></section>}
        {session.stage === 'playing' && <section className="sim-panel sim-play"><h3 tabIndex={-1}>{game.phase === 'insurance' ? 'Insurance?' : 'Your move'}</h3>{game.phase === 'insurance' && <p>Dealer shows an ace. Insurance is a separate half-point stake.</p>}<div className="sim-actions">{simulationChoices(session).map(choice => <button className="sim-button" key={choice} onClick={() => dispatch({ type:'play', choice })}>{simulationChoiceLabels[choice]}</button>)}</div></section>}
        {session.stage === 'decisionFeedback' && lastDecision && <section className="sim-panel sim-feedback" data-testid="simulation-feedback" role="status"><h3 tabIndex={-1}>{lastDecision.correct ? 'Correct decision' : `Recommended: ${simulationChoiceLabels[lastDecision.recommended]}`}</h3><p>{lastDecision.explanation}</p>{!lastDecision.correct && <small>You chose {simulationChoiceLabels[lastDecision.chosen].toLowerCase()}.</small>}<button className="sim-primary" data-testid="simulation-continue" onClick={() => dispatch({ type:'continueDecision' })}>Continue<ArrowRight size={17}/></button></section>}
        {session.stage === 'roundReview' && <section className="sim-panel"><h3 tabIndex={-1}>Round {session.completedRounds + 1} complete</h3><p>{session.configuration.countChecks && !session.countResetDuringRound ? 'Count every revealed card, including the dealer’s hole card, before moving on.' : 'Review the hand before the next round.'}</p>{session.configuration.countChecks && !session.countResetDuringRound ? <button className="sim-primary" onClick={() => dispatch({ type:'checkCount' })}>Check my count<ArrowRight size={17}/></button> : <button className="sim-primary" data-testid="simulation-next-round" onClick={finishRound}>{session.completedRounds + 1 === session.configuration.rounds ? 'See results' : 'Continue to next round'}<ArrowRight size={17}/></button>}</section>}
        {session.stage === 'countCheck' && <form className="sim-panel" onSubmit={event => { event.preventDefault(); if (validCount) dispatch({ type:'count', answer:parsedCount }); }}><h3 tabIndex={-1}>What’s the running count?</h3><p>Include all cards since this shoe began.</p><label className="sim-count-label">Your count<input data-testid="simulation-count" inputMode="text" autoComplete="off" value={countAnswer} onChange={event => setCountAnswer(event.target.value.replace('−','-'))} placeholder="0" maxLength={5}/></label><button type="submit" className="sim-primary" data-testid="simulation-submit-count" disabled={!validCount}>Submit count<ArrowRight size={17}/></button></form>}
        {session.stage === 'countFeedback' && lastCount && <section className="sim-panel" role="status"><h3 tabIndex={-1}>{isTest ? 'Count saved' : lastCount.correct ? 'Correct count' : `Correct count: ${signed(lastCount.expected)}`}</h3><p>{isTest ? 'You’ll review this answer at the end of the session.' : lastCount.correct ? `Continue from ${signed(lastCount.expected)}.` : `You entered ${signed(lastCount.answer)}. Continue from ${signed(lastCount.expected)}.`}</p><button className="sim-primary" data-testid="simulation-next-round" onClick={finishRound}>{session.completedRounds + 1 === session.configuration.rounds ? 'See results' : 'Continue to next round'}<ArrowRight size={17}/></button></section>}
      </>}
      {confirmEnd ? <section className="sim-panel sim-confirm" role="alertdialog" aria-labelledby="sim-end-title"><h3 id="sim-end-title">Discard this simulation?</h3><p>Your unfinished score will not be saved in history.</p><div className="sim-actions"><button ref={keepButtonRef} className="sim-button" onClick={() => setConfirmEnd(false)}>Keep practicing</button><button className="sim-button" onClick={() => { setStore(previous => ({ ...previous, active:null })); setConfirmEnd(false); }}>Discard session</button></div></section> : <button ref={endButtonRef} className="sim-text-button sim-end" onClick={() => setConfirmEnd(true)}><X size={15}/>End session</button>}
    </>}
    <p className="sim-footnote">Simulated cards and practice points only. Never use the app while gambling.</p>
  </section>;
}
