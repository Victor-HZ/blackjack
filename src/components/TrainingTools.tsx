import { useEffect, useId, useMemo, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { ArrowRight, BookOpen, Check, CheckCheck, ChevronRight, Info, Lightbulb, RotateCcw, Sparkles, Target, X } from 'lucide-react';
import { basicStrategy, hiLo } from '../lib/blackjack';
import type { Card, Rules } from '../lib/blackjack';
import './TrainingTools.css';

type TableKind = 'hard' | 'soft' | 'pairs';
type StrategyAction = 'hit' | 'stand' | 'double' | 'split' | 'surrender';
const ranks: Card['rank'][] = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
const dealerRanks: Card['rank'][] = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A'];
const actionLabels: Record<StrategyAction, { letter: string; label: string; detail: string }> = {
  hit: { letter: 'H', label: 'Hit', detail: 'Take another card' },
  stand: { letter: 'S', label: 'Stand', detail: 'Keep your hand' },
  double: { letter: 'D', label: 'Double', detail: 'Double your bet; take one card' },
  split: { letter: 'P', label: 'Split', detail: 'Play two separate hands' },
  surrender: { letter: 'R', label: 'Surrender', detail: 'Give up half your bet' },
};
const card = (rank: Card['rank'], suit: Card['suit'] = '♠'): Card => ({ rank, suit });

function tableRows(kind: TableKind): { label: string; cards: Card[] }[] {
  if (kind === 'soft') return Array.from({ length: 8 }, (_, i) => ({ label: `A, ${i + 2}`, cards: [card('A'), card(String(i + 2) as Card['rank'], '♥')] }));
  if (kind === 'pairs') return [...dealerRanks.slice(0, 9), 'A' as const].map((rank) => ({ label: `${rank}, ${rank}`, cards: [card(rank), card(rank, '♥')] }));
  return Array.from({ length: 16 }, (_, i) => {
    const total = i + 5;
    const first = total < 12 ? Math.floor((total - 1) / 2) : 10;
    return { label: `${total}`, cards: [card(String(first) as Card['rank']), card(String(total - first) as Card['rank'], '♥')] };
  });
}

export function StrategyGuide({ rules, context = 'table' }: { rules: Rules; context?: 'table' | 'simulation' }) {
  const [kind, setKind] = useState<TableKind>('hard');
  const [firstRank, setFirstRank] = useState<Card['rank']>('10');
  const [secondRank, setSecondRank] = useState<Card['rank']>('6');
  const [dealerRank, setDealerRank] = useState<Card['rank']>('10');
  const rows = useMemo(() => tableRows(kind), [kind]);
  const recommendation = basicStrategy([card(firstRank), card(secondRank, '♥')], card(dealerRank), rules);
  const lookupLabel = actionLabels[recommendation.action as StrategyAction];

  return <div className="strategy-layout">
    <section className="strategy-panel strategy-chart-panel" aria-label="Basic strategy chart">
      <div className="strategy-panel-heading">
        <div className="strategy-heading-icon"><BookOpen size={19} /></div>
        <div><h2>Your at-a-glance playbook</h2><p>The right move starts with the right strategy.</p></div>
      </div>
      <div className="strategy-tabs" role="tablist" aria-label="Hand type">
        {(['hard', 'soft', 'pairs'] as const).map((type, index) => <button key={type} id={`strategy-tab-${type}`} role="tab" aria-selected={kind === type} aria-controls="strategy-table-panel" tabIndex={kind === type ? 0 : -1} className={kind === type ? 'active' : ''} onClick={() => setKind(type)} onKeyDown={(event) => {
          if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
          event.preventDefault();
          const tabs: TableKind[] = ['hard', 'soft', 'pairs'];
          const next = event.key === 'Home' ? 0 : event.key === 'End' ? 2 : (index + (event.key === 'ArrowRight' ? 1 : 2)) % 3;
          setKind(tabs[next]);
          document.getElementById(`strategy-tab-${tabs[next]}`)?.focus();
        }}>{type === 'hard' ? 'Hard totals' : type === 'soft' ? 'Soft totals' : 'Pairs'}</button>)}
      </div>
      <p className="strategy-table-caption">{kind === 'hard' ? 'Hands with no ace counted as 11.' : kind === 'soft' ? 'Hands with an ace counted as 11.' : 'Two cards of the same rank. Split when indicated.'}</p>
      <div className="strategy-table-overflow" id="strategy-table-panel" role="tabpanel" aria-labelledby={`strategy-tab-${kind}`}>
        <table className="strategy-table">
          <caption>Dealer’s upcard</caption>
          <thead><tr><th scope="col">Your hand</th>{dealerRanks.map((rank) => <th scope="col" key={rank}>{rank}</th>)}</tr></thead>
          <tbody>{rows.map((row) => <tr key={row.label}><th scope="row">{row.label}</th>{dealerRanks.map((rank) => {
            const advice = basicStrategy(row.cards, card(rank), rules);
            const action = advice.action as StrategyAction;
            const label = actionLabels[action];
            return <td key={rank} className={`strategy-cell strategy-cell-${action}`} title={`${row.label} vs ${rank}: ${label?.label ?? action}. ${advice.reason}`}><span aria-label={label?.label ?? action}>{label?.letter ?? action}</span></td>;
          })}</tr>)}</tbody>
        </table>
      </div>
      <div className="strategy-legend" aria-label="Chart legend">{Object.entries(actionLabels).map(([key, value]) => <div key={key}><span className={`strategy-legend-letter strategy-cell-${key}`}>{value.letter}</span><span>{value.label}</span></div>)}</div>
      <p className="strategy-footnote"><Info size={15} />Initial two-card decisions for 4–8 decks; one- and two-deck deviations are not included. Doubles and splits assume enough chips. When a charted double is unavailable, hit below 18; stand on soft 18 or higher. Surrender appears only when enabled.</p>
    </section>

    <aside className="strategy-sidebar">
      <section className="strategy-panel strategy-lookup">
        <span className="strategy-eyebrow"><Sparkles size={14} /> HAND LOOKUP</span>
        <h2>Unsure about a hand?</h2>
        <p>Set your cards and the dealer’s upcard to find your move.</p>
        <div className="strategy-your-cards"><label>Your first card<select value={firstRank} onChange={(e) => setFirstRank(e.target.value as Card['rank'])}>{ranks.map((rank) => <option key={rank}>{rank}</option>)}</select></label><label>Your second card<select value={secondRank} onChange={(e) => setSecondRank(e.target.value as Card['rank'])}>{ranks.map((rank) => <option key={rank}>{rank}</option>)}</select></label></div>
        <label className="strategy-dealer-select">Dealer’s upcard<select value={dealerRank} onChange={(e) => setDealerRank(e.target.value as Card['rank'])}>{dealerRanks.map((rank) => <option key={rank}>{rank}</option>)}</select></label>
        <div className="strategy-answer" aria-live="polite"><span className={`strategy-answer-symbol strategy-cell-${recommendation.action}`}>{lookupLabel?.letter ?? '✓'}</span><div><span>YOUR BEST MOVE</span><h3>{lookupLabel?.label ?? recommendation.action}</h3></div><ArrowRight size={20} /></div>
        <p className="strategy-answer-reason">{recommendation.reason}</p>
      </section>
      <section className="strategy-rule-card"><div><Lightbulb size={19} /><h3>{context === 'simulation' ? 'Simulation rules' : 'Know your table'}</h3></div><p>{rules.decks < 4 ? 'Your table uses fewer than four decks. This guide shows multi-deck strategy; single- and double-deck deviations are not included.' : context === 'simulation' ? 'This chart uses the saved rules from your simulation. Your practice table is unchanged.' : 'This chart uses your current table rules. A change in the rules can change the right play.'}</p><dl><div><dt>Decks</dt><dd>{rules.decks}</dd></div><div><dt>Dealer soft 17</dt><dd>{rules.hitSoft17 ? 'Hits' : 'Stands'}</dd></div><div><dt>Double after split</dt><dd>{rules.doubleAfterSplit ? 'Allowed' : 'Not allowed'}</dd></div><div><dt>Late surrender</dt><dd>{rules.surrender ? 'Allowed' : 'Not allowed'}</dd></div></dl><p className="strategy-small-note">Basic strategy reduces the house edge. It does not guarantee a win.</p></section>
    </aside>
  </div>;
}

const drillLength = 20;
function createDrill(): Card[] {
  const cards: Card[] = [];
  for (const suit of ['♠', '♥', '♦', '♣'] as const) for (const rank of ranks) cards.push({ rank, suit });
  for (let i = cards.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [cards[i], cards[j]] = [cards[j], cards[i]];
  }
  return cards.slice(0, drillLength);
}

function DrillCard({ value, small = false }: { value: Card; small?: boolean }) {
  const red = value.suit === '♥' || value.suit === '♦';
  return <div className={`counting-card${red ? ' counting-card-red' : ''}${small ? ' counting-card-small' : ''}`} aria-label={`${value.rank} of ${value.suit === '♠' ? 'spades' : value.suit === '♥' ? 'hearts' : value.suit === '♦' ? 'diamonds' : 'clubs'}`}><span className="counting-card-corner">{value.rank}<small>{value.suit}</small></span><span className="counting-card-suit" aria-hidden="true">{value.suit}</span><span className="counting-card-corner counting-card-bottom" aria-hidden="true">{value.rank}<small>{value.suit}</small></span></div>;
}

export function CountingDrill({ onComplete }: { onComplete?: (correct: boolean) => void }) {
  const [cards, setCards] = useState(createDrill);
  const [index, setIndex] = useState(0);
  const [answer, setAnswer] = useState('');
  const [checked, setChecked] = useState(false);
  const [correct, setCorrect] = useState(0);
  const [lastCorrect, setLastCorrect] = useState(false);
  const [finished, setFinished] = useState(false);
  const inputId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const currentCard = cards[index];
  const expectedCount = cards.slice(0, index + 1).reduce((sum, value) => sum + hiLo(value), 0);
  const currentValue = hiLo(currentCard);
  const answered = index + (checked ? 1 : 0);
  const formatted = (number: number) => number > 0 ? `+${number}` : `${number}`;
  useEffect(() => { if (index > 0) inputRef.current?.focus(); }, [index]);

  function reset() {
    setCards(createDrill()); setIndex(0); setAnswer(''); setChecked(false); setCorrect(0); setFinished(false); setLastCorrect(false);
  }
  function checkAnswer(e: FormEvent) {
    e.preventDefault();
    if (checked || answer.trim() === '' || !Number.isInteger(Number(answer))) return;
    const isCorrect = Number(answer) === expectedCount;
    setLastCorrect(isCorrect); setChecked(true);
    if (isCorrect) setCorrect((previous) => previous + 1);
    onComplete?.(isCorrect);
  }
  function nextCard() {
    if (index === drillLength - 1) { setFinished(true); return; }
    setIndex((previous) => previous + 1); setChecked(false); setAnswer('');
  }

  return <div className="counting-layout">
    <section className="counting-drill-panel" aria-label="Card counting drill">
      <div className="counting-drill-header"><span className="strategy-eyebrow"><Target size={14} /> HI-LO PRACTICE</span><button type="button" onClick={reset}><RotateCcw size={15} />New drill</button></div>
      <div className="counting-progress-heading"><span>{finished ? 'Drill complete' : `Card ${index + 1} of ${drillLength}`}</span><span>{correct} correct</span></div><div className="counting-progress" role="progressbar" aria-label="Cards answered" aria-valuemin={0} aria-valuemax={drillLength} aria-valuenow={answered}><div style={{ width: `${answered / drillLength * 100}%` }} /></div>
      {finished ? <div className="counting-complete"><div className="counting-complete-icon"><CheckCheck size={33} /></div><span className="strategy-eyebrow">PRACTICE MAKES PROGRESS</span><h2>{correct === drillLength ? 'A perfect count.' : correct >= 15 ? 'You’re finding your rhythm.' : 'Every card is a fresh start.'}</h2><p>You got <strong>{correct} of {drillLength}</strong> counts right.</p><div className="counting-final-score">{Math.round(correct / drillLength * 100)}<span>% accuracy</span></div><button className="counting-primary" type="button" onClick={reset}>Practice again <ArrowRight size={17} /></button></div> : <>
        <div className="counting-table"><span className="counting-table-instruction">{index === 0 ? 'Start your running count at 0' : 'Add this card to your running count'}</span><div className="counting-current-card" key={index}><DrillCard value={currentCard} /></div><span className="counting-table-mark">ONE CARD. ONE BETTER HABIT.</span></div>
        <div className="counting-response"><form onSubmit={checkAnswer}><label htmlFor={inputId}>What’s the running count?</label><div className="counting-input-row"><input id={inputId} ref={inputRef} key={`input-${index}`} type="number" inputMode="numeric" step="1" value={answer} placeholder="e.g. −2, 0, +3" onChange={(e) => setAnswer(e.target.value)} disabled={checked} autoComplete="off" aria-describedby={`${inputId}-help`} /><button className="counting-primary" type="submit" disabled={checked || answer.trim() === '' || !Number.isInteger(Number(answer))}>Check count <ChevronRight size={17} /></button></div></form><p id={`${inputId}-help`} className="counting-help">Keep the total in your head as each card appears.</p>
        {checked && <div className={`counting-feedback ${lastCorrect ? 'counting-feedback-correct' : 'counting-feedback-incorrect'}`} role="status"><div>{lastCorrect ? <Check size={19} /> : <X size={19} />}<p><strong>{lastCorrect ? 'That’s right!' : `The running count is ${formatted(expectedCount)}.`}</strong><span>{currentCard.rank} is worth {formatted(currentValue)}. {formatted(expectedCount - currentValue)} {currentValue < 0 ? '−' : '+'} {Math.abs(currentValue)} = {formatted(expectedCount)}.</span></p></div><button type="button" onClick={nextCard}>{index === drillLength - 1 ? 'See results' : 'Next card'}<ArrowRight size={16} /></button></div>}
        </div>
      </>}
      {index > 0 && !finished && <div className="counting-history"><span>RECENT CARDS</span><div>{cards.slice(Math.max(0, index - 6), index).map((value, i) => <DrillCard key={`${index}-${i}`} value={value} small />)}</div></div>}
    </section>
    <aside className="counting-sidebar"><section className="strategy-panel counting-guide"><div className="strategy-heading-icon"><Lightbulb size={20} /></div><h2>Small numbers.<br />A sharper game.</h2><p>Hi-Lo assigns a value to every card. Add each value to your running count.</p><div className="counting-value-row"><span className="counting-value counting-value-plus">+1</span><div><strong>Low cards</strong><span>2, 3, 4, 5, 6</span></div></div><div className="counting-value-row"><span className="counting-value counting-value-zero">0</span><div><strong>Neutral cards</strong><span>7, 8, 9</span></div></div><div className="counting-value-row"><span className="counting-value counting-value-minus">−1</span><div><strong>High cards</strong><span>10, J, Q, K, A</span></div></div><div className="counting-tip"><Sparkles size={17} /><p>Start slowly. Accuracy comes first; speed follows with practice.</p></div></section><section className="strategy-rule-card"><h3>Running count vs. true count</h3><p>This drill trains your running count. At a multi-deck table, divide that count by the decks remaining to estimate the true count.</p><div className="counting-formula"><span>Running count</span><span>÷</span><span>Decks remaining</span></div><p className="strategy-small-note">A high count does not guarantee a winning hand. Practice here uses virtual cards only.</p></section></aside>
  </div>;
}
