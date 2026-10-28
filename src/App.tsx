import { useCallback, useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { ArrowDown, ArrowRight, ArrowUpRight, BarChart3, BookOpen, Check, ChevronRight, CircleHelp, Club, Download, Flag, GraduationCap, Layers3, Lightbulb, Menu, Minus, Plus, RotateCcw, Settings2, ShieldCheck, Sparkles, Spade, Split, Target, TrendingUp, Wallet, X } from 'lucide-react';
import { availableActions, basicStrategy, createGame, DEFAULT_RULES, gameReducer, score, trueCount } from './lib/blackjack';
import type { Card, GameAction, GameState, Move, Rules } from './lib/blackjack';
import { CountingDrill, StrategyGuide } from './components/TrainingTools';
import { validateSavedPractice } from './lib/storage';
import type { PracticeStats as Stats, SavedPractice as Stored } from './lib/storage';

type Page = 'practice' | 'strategy' | 'counting' | 'progress';
const STORAGE_KEY = 'blackjack-studio:v1';
const emptyStats = (): Stats => ({ decisions: 0, correct: 0, drills: 0, correctDrills: 0 });
const initial = (): Stored => ({ version: 1, game: createGame(), stats: emptyStats(), showHints: true, showCount: true, bet: 25 });
const credits = (value: number) => value.toLocaleString('en-US', { maximumFractionDigits: 2 });
const signed = (value: number) => `${value > 0 ? '+' : ''}${credits(value)}`;
const actionLabels: Record<Move, string> = { hit: 'Hit', stand: 'Stand', double: 'Double', split: 'Split', surrender: 'Surrender' };
const actionKeys: Record<Move, string> = { hit: 'H', stand: 'S', double: 'D', split: 'P', surrender: 'R' };
const actionIcons: Record<Move, typeof Plus> = { hit: Plus, stand: Minus, double: ArrowUpRight, split: Split, surrender: Flag };
function load(): Stored {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return initial();
    const value: unknown = JSON.parse(raw);
    if (!validateSavedPractice(value)) return initial();
    return value;
  } catch { return initial(); }
}

function PlayingCard({ card, hidden = false, small = false }: { card?: Card; hidden?: boolean; small?: boolean }) {
  if (hidden || !card) return <div className={`playing-card card-back ${small ? 'small-card' : ''}`} aria-label="Face-down card"><div><Spade strokeWidth={1.1} /></div></div>;
  return <div className={`playing-card ${card.suit === '♥' || card.suit === '♦' ? 'red-card' : ''} ${small ? 'small-card' : ''}`} aria-label={`${card.rank} of ${{ '♠':'spades', '♥':'hearts', '♦':'diamonds', '♣':'clubs' }[card.suit]}`}><span className="card-corner">{card.rank}<i>{card.suit}</i></span><span className="card-suit">{card.suit}</span><span className="card-corner bottom-corner">{card.rank}<i>{card.suit}</i></span></div>;
}
function Toggle({ checked, onChange, label }: { checked: boolean; onChange: () => void; label: string }) {
  return <button type="button" className={`toggle ${checked ? 'on' : ''}`} role="switch" aria-checked={checked} aria-label={label} onClick={onChange}><span /></button>;
}
function Modal({ title, children, onClose }: { title: string; children: ReactNode; onClose: () => void }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    const node = ref.current;
    node?.querySelector<HTMLButtonElement>('button')?.focus();
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
      if (event.key !== 'Tab' || !node) return;
      const items = [...node.querySelectorAll<HTMLElement>('button:not(:disabled), select:not(:disabled), input:not(:disabled), [tabindex="0"]')];
      if (event.shiftKey && document.activeElement === items[0]) { event.preventDefault(); items.at(-1)?.focus(); }
      if (!event.shiftKey && document.activeElement === items.at(-1)) { event.preventDefault(); items[0]?.focus(); }
    };
    document.addEventListener('keydown', onKey);
    const old = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => { document.removeEventListener('keydown', onKey); document.body.style.overflow = old; previous?.focus(); };
  }, [onClose]);
  return <div className="modal-backdrop" onClick={onClose}><div className="modal" role="dialog" aria-modal="true" aria-label={title} ref={ref} onClick={e => e.stopPropagation()}><div className="modal-heading"><h2>{title}</h2><button className="icon-button" aria-label="Close dialog" onClick={onClose}><X size={20}/></button></div>{children}</div></div>;
}

export default function App() {
  const [data, setData] = useState<Stored>(load);
  const [page, setPage] = useState<Page>('practice');
  const [mobileMenu, setMobileMenu] = useState(false);
  const [modal, setModal] = useState<'help' | 'settings' | null>(null);
  const closeModal = useCallback(() => setModal(null), []);
  const [draftRules, setDraftRules] = useState<Rules>(data.game.rules);
  const [resetConfirm, setResetConfirm] = useState(false);
  const [feedback, setFeedback] = useState<{ correct: boolean; action: Move; reason: string } | null>(null);
  const [storageError, setStorageError] = useState(false);
  const { game, stats, showHints, showCount, bet } = data;
  const playing = game.phase === 'playing';
  const roundActive = playing || game.phase === 'insurance';
  const actions = availableActions(game);
  const hand = game.hands[game.activeHand];
  const advice = playing && hand ? basicStrategy(hand.cards, game.dealer[0], game.rules, { canDouble: actions.includes('double'), canSplit: actions.includes('split'), canSurrender: actions.includes('surrender'), fromSplit: hand.fromSplit }) : null;
  const accuracy = stats.decisions ? Math.round(stats.correct / stats.decisions * 100) : null;
  const lastRound = game.history.at(-1);
  const profit = (game.history.at(-1)?.bankroll ?? 1000) - 1000;
  const wins = game.history.filter(h => h.profit > 0).length;
  useEffect(() => {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(data)); setStorageError(false); }
    catch { setStorageError(true); }
  }, [data]);
  function act(action: GameAction) {
    if (action.type === 'deal' || action.type === 'shuffle') setFeedback(null);
    if (playing && advice && actions.includes(action.type as Move)) setFeedback({ correct: action.type === advice.action, action: advice.action, reason: advice.reason });
    setData(previous => {
      const next = gameReducer(previous.game, action);
      if (next === previous.game) return previous;
      const available = availableActions(previous.game);
      let nextStats = previous.stats;
      if (previous.game.phase === 'playing' && available.includes(action.type as Move)) {
        const active = previous.game.hands[previous.game.activeHand];
        const suggested = basicStrategy(active.cards, previous.game.dealer[0], previous.game.rules, { canDouble: available.includes('double'), canSplit: available.includes('split'), canSurrender: available.includes('surrender'), fromSplit: active.fromSplit });
        nextStats = { ...nextStats, decisions: nextStats.decisions + 1, correct: nextStats.correct + Number(suggested.action === action.type) };
      }
      return { ...previous, game: next, stats: nextStats };
    });
  }
  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement;
      if (page !== 'practice' || modal || event.ctrlKey || event.metaKey || event.altKey || ['INPUT','SELECT','TEXTAREA'].includes(target.tagName)) return;
      const key = event.key.toLowerCase();
      const move = ({ h:'hit', s:'stand', d:'double', p:'split', r:'surrender' } as const)[key as 'h'];
      if (move && actions.includes(move)) { event.preventDefault(); act({ type: move }); }
      if (key === 'enter' && !roundActive && target.tagName !== 'BUTTON' && bet >= 1 && bet <= game.bankroll) { event.preventDefault(); act({ type: 'deal', bet }); }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  });
  const go = (destination: Page) => { setPage(destination); setMobileMenu(false); };
  const openSettings = () => { setDraftRules(game.rules); setResetConfirm(false); setModal('settings'); };
  const navigation: { page: Page; label: string; icon: typeof Spade; caption: string }[] = [
    { page:'practice', label:'Practice table', icon:Spade, caption:'PLAY & LEARN' },
    { page:'strategy', label:'Strategy guide', icon:BookOpen, caption:'THE RIGHT MOVE' },
    { page:'counting', label:'Card counting', icon:Layers3, caption:'TRAIN YOUR EDGE' },
    { page:'progress', label:'Your progress', icon:BarChart3, caption:'BUILD YOUR CONFIDENCE' },
  ];
  const headings: Record<Page, { eyebrow: string; title: string; subtitle: string }> = {
    practice: { eyebrow:'YOUR DAILY PRACTICE', title:'Make your next move better.', subtitle:'A little practice. A sharper instinct. Take a seat at the table.' },
    strategy: { eyebrow:'THE RIGHT MOVE, EVERY TIME', title:'Build a better instinct.', subtitle:'Learn the numbers behind the decisions. One hand at a time.' },
    counting: { eyebrow:'TRAIN YOUR EDGE', title:'Keep your eye on the count.', subtitle:'Turn a little focus into a skill that stays with you.' },
    progress: { eyebrow:'SMALL STEPS. REAL PROGRESS.', title:'See how far you’ve come.', subtitle:'Your practice, in perspective. Every decision is a chance to learn.' },
  };
  function exportHistory() {
    const csv = ['Round,Bet,Net result,Bankroll,Outcomes', ...game.history.map(h => `${h.id},${h.bet},${h.profit},${h.bankroll},${h.outcomes.join(' / ')}`)].join('\n');
    const url = URL.createObjectURL(new Blob([csv], { type:'text/csv' }));
    const link = document.createElement('a'); link.href = url; link.download = 'blackjack-practice.csv'; link.click(); URL.revokeObjectURL(url);
  }
  return <div className="app-layout">
    {mobileMenu && <div className="sidebar-scrim" onClick={() => setMobileMenu(false)} />}
    <aside className={`sidebar ${mobileMenu ? 'is-open' : ''}`}>
      <button className="brand" onClick={() => go('practice')} aria-label="Blackjack Studio home"><span className="brand-mark"><Spade size={26} fill="currentColor" strokeWidth={1}/></span><span>blackjack<span className="brand-studio">STUDIO</span></span></button>
      <div className="nav-label">YOUR WORKSPACE</div>
      <nav aria-label="Main navigation">{navigation.map(item => <button key={item.page} className={`nav-item ${page === item.page ? 'active' : ''}`} onClick={() => go(item.page)} aria-current={page === item.page ? 'page' : undefined}><item.icon size={19}/><span>{item.label}</span>{page === item.page && <span className="nav-dot"/>}</button>)}</nav>
      <div className="sidebar-note"><div className="note-icon"><GraduationCap size={23}/></div><h3>Skill, not luck.</h3><p>Better decisions start with a little practice.</p><button onClick={() => go('strategy')}>Learn the fundamentals <ArrowUpRight size={15}/></button><div className="note-art" aria-hidden="true">♠</div></div>
      <div className="sidebar-bottom"><button className="nav-item" onClick={openSettings}><Settings2 size={19}/><span>Table settings</span></button><button className="nav-item" onClick={() => setModal('help')}><CircleHelp size={19}/><span>How to play</span></button><div className="local-profile"><div className="avatar">You</div><div><strong>Your practice space</strong><span>Saved on this device</span></div><ShieldCheck size={17}/></div></div>
    </aside>
    <div className="main-shell">
      <header className="topbar"><div className="breadcrumb"><button className="icon-button mobile-menu-button" aria-label="Open navigation" onClick={() => setMobileMenu(true)}><Menu size={21}/></button><span>Workspace</span><ChevronRight size={14}/><strong>{navigation.find(n => n.page === page)?.label}</strong></div><div className="topbar-right"><span className="practice-pill"><span/>PRACTICE MODE</span><button className="icon-button" aria-label="Help" onClick={() => setModal('help')}><CircleHelp size={20}/></button><span className="small-avatar">Y</span></div></header>
      <main>
        <div className="page-heading"><div><div className="eyebrow">{headings[page].eyebrow}</div><h1>{headings[page].title}</h1><p>{headings[page].subtitle}</p></div><button className="outline-button settings-button" onClick={openSettings}><Settings2 size={16}/> Table settings</button></div>
        {storageError && <div className="notice" role="status">Your browser is blocking local storage. You can play, but this session won’t be saved after closing the page.</div>}
        {page === 'practice' && <>
          <section className="stat-row" aria-label="Practice statistics"><Stat icon={<Wallet size={20}/>} label="Practice bankroll" value={credits(game.bankroll)} suffix="credits" foot={<><span className={profit < 0 ? 'negative' : 'positive'}>{signed(profit)}</span> this session</>}/><Stat icon={<Target size={20}/>} label="Strategy accuracy" value={accuracy === null ? '—' : `${accuracy}%`} foot={stats.decisions ? `${stats.correct} of ${stats.decisions} decisions on point` : 'Your first decision starts the story'}/><Stat icon={<Layers3 size={20}/>} label="Hands played" value={String(game.rounds)} foot={game.rounds ? `${wins} wins in recent history` : 'A fresh table. A fresh start.'}/></section>
          <div className="practice-layout"><section className="game-panel" aria-label="Blackjack practice table">
            <div className="table-heading"><div><span className="live-dot"/><h2>The practice table</h2></div><span>{game.rules.decks} decks <span className="separator-dot">·</span> {game.rules.hitSoft17 ? 'Dealer hits soft 17' : 'Dealer stands on 17'}</span></div>
            <div className="felt-table">
              <div className="felt-line" aria-hidden="true"/><span className="table-corner left-corner" aria-hidden="true">♣</span><span className="table-corner right-corner" aria-hidden="true">♦</span>
              <div className="shoe-indicator"><Layers3 size={15}/><span>{(game.shoe.length / 52).toFixed(1)} decks left</span></div>
              <div className="dealer-zone"><div className="seat-label">DEALER {game.dealer.length > 0 && <span className="total-pill">{score(game.holeRevealed ? game.dealer : game.dealer.slice(0,1)).total}{!game.holeRevealed && ' + ?'}</span>}</div><div className="cards-row">{game.dealer.length ? game.dealer.map((card,i) => <PlayingCard key={i} card={card} hidden={i === 1 && !game.holeRevealed} small/>) : <><PlayingCard hidden small/><PlayingCard hidden small/></>}</div></div>
              <div className="table-brand" aria-hidden="true"><div className="table-brand-row"><span/><Spade size={18} fill="currentColor" strokeWidth={1}/><span/></div><strong>BLACKJACK PAYS {game.rules.blackjackPayout.replace(':',' TO ')}</strong><span>INSURANCE PAYS 2 TO 1</span></div>
              <div className={`player-zone ${game.hands.length > 1 ? 'split-zone' : ''}`}>
                {game.hands.length ? game.hands.map((playerHand,i) => <div key={i} className={`hand-group ${roundActive && game.activeHand === i ? 'active-hand' : ''}`}><div className="cards-row">{playerHand.cards.map((card,j) => <PlayingCard key={j} card={card}/>)}</div><div className="seat-label">{game.hands.length > 1 ? `HAND ${i+1}` : 'YOUR HAND'}<span className={`total-pill ${score(playerHand.cards).bust ? 'bust-total' : ''}`}>{score(playerHand.cards).total}{score(playerHand.cards).soft && ' soft'}</span>{playerHand.outcome && <span className="hand-outcome">{playerHand.outcome}</span>}</div><span className="table-wager">{credits(playerHand.bet)} credits</span></div>) : <div className="empty-hand"><div className="empty-card"><Spade size={28} strokeWidth={1}/></div><div className="empty-card"><Club size={28} strokeWidth={1}/></div><span>Your seat is ready.</span></div>}
              </div>
              {game.phase === 'settled' && <div className={`round-result ${lastRound && lastRound.profit < 0 ? 'result-loss' : ''}`} role="status">{lastRound && lastRound.profit > 0 ? <Sparkles size={16}/> : lastRound && lastRound.profit < 0 ? <ArrowDown size={16}/> : <Minus size={16}/>} {game.message}</div>}
            </div>
            <div className="action-dock">
              {!roundActive ? <><div className="wager-controls"><label htmlFor="wager">YOUR BET <span>practice credits</span></label><div className="bet-options">{[5,25,50,100].map(amount => <button key={amount} className={`chip-button ${bet === amount ? 'selected' : ''}`} onClick={() => setData(d => ({...d,bet:amount}))} disabled={amount > game.bankroll}>{amount}</button>)}<input id="wager" aria-label="Custom bet" type="number" min="1" max={game.bankroll} step="0.01" value={bet || ''} onChange={e => setData(d => ({ ...d,bet:Number.isFinite(Number(e.target.value)) ? Math.max(0,Number(e.target.value)) : 0 }))}/></div></div><button className="primary-button deal-button" onClick={() => act({type:'deal',bet})} disabled={bet < 1 || bet > game.bankroll}>{game.rounds ? 'Deal next hand' : 'Deal a hand'}<ArrowRight size={19}/></button>{game.bankroll < 1 && <div className="bankroll-empty">Practice bankroll used up. <button onClick={openSettings}>Reset your session</button> to keep learning.</div>}</> : game.phase === 'insurance' ? <div className="insurance-controls"><div><strong>Dealer shows an ace.</strong><p>Insure this hand for {credits(game.hands[0].bet / 2)} credits?</p></div><button className="outline-button" onClick={() => act({type:'insurance'})} disabled={game.bankroll < game.hands[0].bet / 2}>Take insurance</button><button className="primary-button" onClick={() => act({type:'declineInsurance'})}>No insurance<ArrowRight size={16}/></button></div> : <div className="move-buttons">{(['hit','stand','double','split','surrender'] as Move[]).map(move => { const Icon = actionIcons[move]; return <button key={move} className={`move-button ${showHints && advice?.action === move ? 'recommended-move' : ''}`} onClick={() => act({type:move})} disabled={!actions.includes(move)}><Icon size={19}/><span>{actionLabels[move]}</span><kbd>{actionKeys[move]}</kbd></button>; })}</div>}
            </div>
            <div className="table-bottom"><span><ShieldCheck size={14}/> No real money. Just real improvement.</span><button disabled={roundActive} onClick={() => act({type:'shuffle'})}><RotateCcw size={13}/> New shoe</button></div>
          </section>
          <aside className="coach-column"><section className="coach-card"><div className="panel-heading"><div className="icon-label"><Lightbulb size={19}/><h2>Your strategy coach</h2></div><Toggle label="Show strategy hints" checked={showHints} onChange={() => setData(d => ({...d,showHints:!d.showHints}))}/></div><span className="mini-label">{showHints ? 'A LITTLE GUIDANCE GOES A LONG WAY' : 'TRUST YOUR INSTINCT'}</span><div className="coach-symbol"><Sparkles size={27} strokeWidth={1.3}/></div><h3>{!showHints ? 'You’ve got this.' : advice ? `${actionLabels[advice.action]} is the move.` : game.phase === 'insurance' ? 'Skip the insurance.' : game.phase === 'settled' ? 'Every hand teaches you.' : 'Let’s build your instinct.'}</h3><p>{!showHints ? 'Hints are hidden. Make your decision, then switch the coach on to review it.' : advice ? advice.reason : game.phase === 'insurance' ? 'Basic strategy declines insurance. This side bet doesn’t improve your main hand.' : game.phase === 'settled' ? 'Good strategy is about making the right decision over time, regardless of this hand’s result.' : 'Deal a hand and we’ll help you find the right play, with the reasoning behind it.'}</p>{showHints && advice && <div className="suggested-action"><span>RECOMMENDED</span><strong>{actionLabels[advice.action]}<ArrowUpRight size={16}/></strong></div>}{showHints && feedback && <div className={`decision-feedback ${feedback.correct ? 'correct' : 'incorrect'}`} role="status"><strong>{feedback.correct ? <Check size={15}/> : <Lightbulb size={15}/>} {feedback.correct ? 'Good decision.' : `Last move: ${actionLabels[feedback.action]} was better.`}</strong><span>{feedback.reason}</span></div>}<button className="text-link" onClick={() => go('strategy')}>Explore basic strategy <ArrowRight size={15}/></button></section>
            <section className="count-card"><div className="panel-heading"><div className="icon-label"><Layers3 size={18}/><h2>The count</h2></div><Toggle label="Show card count" checked={showCount} onChange={() => setData(d => ({...d,showCount:!d.showCount}))}/></div><div className="count-values"><div><span>Running</span><strong>{showCount ? signed(game.runningCount) : '••'}</strong></div><div><span>True count</span><strong>{showCount ? `${trueCount(game) > 0 ? '+' : ''}${trueCount(game).toFixed(1)}` : '••'}</strong></div></div><div className="shoe-progress"><span style={{width:`${Math.min(100,game.shoe.length / (game.rules.decks * 52) * 100)}%`}}/></div><div className="shoe-caption"><span>Hi-Lo system</span><span>{game.shoe.length} cards remaining</span></div><button className="text-link" onClick={() => go('counting')}>Train your counting <ArrowRight size={15}/></button></section>
          </aside></div>
          <section className="bottom-insight"><span className="insight-icon"><BookOpen size={20}/></span><div><strong>The goal isn’t to win every hand. It’s to play every hand well.</strong><p>Consistent decisions make the difference. Your coach follows multi-deck basic strategy.</p></div><button onClick={() => go('progress')}>View your progress<ArrowUpRight size={17}/></button></section>
        </>}
        {page === 'strategy' && <StrategyGuide rules={game.rules}/>}
        {page === 'counting' && <CountingDrill onComplete={correct => setData(d => ({...d,stats:{...d.stats,drills:d.stats.drills+1,correctDrills:d.stats.correctDrills+Number(correct)}}))}/>}
        {page === 'progress' && <>
          <section className="stat-row"><Stat icon={<Target size={20}/>} label="Strategy accuracy" value={accuracy === null ? '—' : `${accuracy}%`} foot={`${stats.correct} correct of ${stats.decisions} decisions`}/><Stat icon={<TrendingUp size={20}/>} label="Session result" value={signed(profit)} suffix="credits" foot={`${game.rounds} rounds played`}/><Stat icon={<Layers3 size={20}/>} label="Counting accuracy" value={stats.drills ? `${Math.round(stats.correctDrills/stats.drills*100)}%` : '—'} foot={`${stats.correctDrills} correct of ${stats.drills} checks`}/></section>
          <section className="progress-card"><div className="section-heading"><div><h2>Your bankroll journey</h2><p>Practice results fluctuate. Focus on the quality of your decisions.</p></div><span className="badge">{game.history.length ? `Last ${game.history.length} rounds` : 'This session'}</span></div>{game.history.length > 1 ? <BankrollChart history={game.history}/> : <div className="empty-progress"><BarChart3 size={35} strokeWidth={1.2}/><h3>Your story starts at the table.</h3><p>Play a few hands to see your practice bankroll over time.</p><button className="primary-button" onClick={() => go('practice')}>Take a seat <ArrowRight size={17}/></button></div>}</section>
          <section className="history-card"><div className="section-heading"><div><h2>Recent hands</h2><p>Your last 20 rounds, at a glance.</p></div><button className="outline-button" disabled={!game.history.length} onClick={exportHistory}><Download size={15}/> Export CSV</button></div>{!game.history.length ? <p className="empty-history">No completed rounds yet. Your hands will appear here after you play.</p> : <div className="history-scroll"><table><thead><tr><th>Round</th><th>Result</th><th>Total bet</th><th>Net credits</th><th>Bankroll</th></tr></thead><tbody>{game.history.slice(-20).reverse().map(round => <tr key={round.id}><td>#{round.id}</td><td><span className={`result-badge ${round.profit > 0 ? 'win' : round.profit < 0 ? 'loss' : ''}`}>{round.outcomes.join(' / ')}</span></td><td>{credits(round.bet)}</td><td className={round.profit < 0 ? 'negative' : 'positive'}>{signed(round.profit)}</td><td>{credits(round.bankroll)}</td></tr>)}</tbody></table></div>}</section>
        </>}
        <footer className="page-footer"><span>Made for the love of a better game.</span><span><Spade size={12} fill="currentColor"/> BLACKJACK STUDIO</span></footer>
      </main>
    </div>
    {modal === 'help' && <Modal title="A better game starts here." onClose={closeModal}><p className="modal-intro">Get closer to 21 than the dealer, without going over. An ace counts as 1 or 11; picture cards count as 10.</p><div className="help-grid">{[{title:'1. Choose your bet',text:'Select a chip or enter an amount, then deal. All bets use practice credits.'},{title:'2. Make your move',text:'Hit for another card, stand to keep your total, double for one final card at twice the bet, or split a pair into two hands.'},{title:'3. Learn as you play',text:'Your coach explains basic strategy. Turn hints and counts off to challenge yourself, then check your progress.'}].map(item => <div key={item.title}><h3>{item.title}</h3><p>{item.text}</p></div>)}</div><div className="help-note"><Lightbulb size={19}/><p>Late surrender returns half your bet. Insurance is a separate bet on the dealer having blackjack. Split aces receive one additional card each, and a split 21 pays as a regular win.</p></div><h3 className="shortcut-heading">A few useful shortcuts</h3><div className="shortcuts">{Object.entries(actionKeys).map(([move,key]) => <span key={move}><kbd>{key}</kbd>{actionLabels[move as Move]}</span>)}<span><kbd>↵</kbd>Deal</span></div><button className="primary-button full-button" onClick={() => setModal(null)}>Let’s play<ArrowRight size={17}/></button></Modal>}
    {modal === 'settings' && <Modal title="Make the table yours." onClose={closeModal}><p className="modal-intro">Practice the rules you’ll encounter at the table. Rule changes start a fresh shoe and preserve your bankroll and results.</p><div className="settings-fields"><label className="setting-row"><span><strong>Number of decks</strong><small>Strategy coach supports 4–8 deck games</small></span><select value={draftRules.decks} onChange={e => setDraftRules(r => ({...r,decks:Number(e.target.value) as Rules['decks']}))}>{[4,6,8].map(n => <option key={n} value={n}>{n} decks</option>)}</select></label><label className="setting-row"><span><strong>Blackjack payout</strong><small>For a natural, unsplit blackjack</small></span><select value={draftRules.blackjackPayout} onChange={e => setDraftRules(r => ({...r,blackjackPayout:e.target.value as Rules['blackjackPayout']}))}><option value="3:2">3 to 2</option><option value="6:5">6 to 5</option></select></label><div className="setting-row"><span><strong>Dealer hits soft 17</strong><small>Otherwise the dealer stands on all 17s</small></span><Toggle label="Dealer hits soft 17" checked={draftRules.hitSoft17} onChange={() => setDraftRules(r => ({...r,hitSoft17:!r.hitSoft17}))}/></div><div className="setting-row"><span><strong>Double after split</strong><small>Allow doubling on split hands</small></span><Toggle label="Double after split" checked={draftRules.doubleAfterSplit} onChange={() => setDraftRules(r => ({...r,doubleAfterSplit:!r.doubleAfterSplit}))}/></div><div className="setting-row"><span><strong>Late surrender</strong><small>Give up an initial hand for half your bet</small></span><Toggle label="Late surrender" checked={draftRules.surrender} onChange={() => setDraftRules(r => ({...r,surrender:!r.surrender}))}/></div></div>{roundActive && <p className="notice">Finish the current hand before changing the rules or resetting your session.</p>}<button className="primary-button full-button" disabled={roundActive} onClick={() => { setData(d => ({...d,game:{...createGame({bankroll:d.game.bankroll,rules:draftRules}),rounds:d.game.rounds,history:d.game.history}})); setFeedback(null); setModal(null); }}><Check size={17}/>Save table settings</button><div className="reset-section"><div><strong>A fresh start</strong><p>Reset your bankroll to 1,000 and clear practice statistics.</p></div><button className={`outline-button ${resetConfirm ? 'danger-button' : ''}`} disabled={roundActive} onClick={() => { if (!resetConfirm) {setResetConfirm(true);return;} setData({...initial(),game:createGame({rules:game.rules}),showHints,showCount}); setFeedback(null); setModal(null); }}>{resetConfirm ? 'Confirm reset' : 'Reset practice'}</button></div><button className="subtle-link" onClick={() => setDraftRules(DEFAULT_RULES)}>Restore default rules</button></Modal>}
  </div>;
}
function Stat({ icon,label,value,suffix,foot }: { icon:ReactNode;label:string;value:string;suffix?:string;foot:ReactNode }) {
  return <div className="stat-card"><div className="stat-icon">{icon}</div><div><span className="stat-label">{label}</span><div className="stat-value">{value}{suffix && <span>{suffix}</span>}</div><div className="stat-foot">{foot}</div></div></div>;
}
function BankrollChart({history}: {history:GameState['history']}) {
  const values = [history[0].bankroll-history[0].profit,...history.map(h=>h.bankroll)];
  const min = Math.min(...values)-20, max = Math.max(...values)+20;
  const points = values.map((v,i)=>`${48+i/(values.length-1)*900},${200-(v-min)/(max-min)*160}`).join(' ');
  return <div className="bankroll-chart"><svg viewBox="0 0 1000 245" role="img" aria-label={`Bankroll over ${history.length} rounds, starting at ${credits(values[0])}, ending at ${credits(values.at(-1)!)}`}><defs><linearGradient id="chart-fill" x1="0" x2="0" y1="0" y2="1"><stop offset="0%" stopColor="#b6d5a4" stopOpacity="0.5"/><stop offset="100%" stopColor="#b6d5a4" stopOpacity="0"/></linearGradient></defs>{[40,120,200].map((y,i)=><g key={y}><line x1="48" x2="948" y1={y} y2={y} stroke="#e9ede7" strokeDasharray="4 5"/><text x="0" y={y+4} fontSize="11" fill="#7c8780">{Math.round(max-(max-min)*i/2)}</text></g>)}<polygon points={`48,200 ${points} 948,200`} fill="url(#chart-fill)"/><polyline points={points} fill="none" stroke="#357254" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/><text x="48" y="232" fontSize="12" fill="#7c8780">Start</text><text x="948" y="232" fontSize="12" fill="#7c8780" textAnchor="end">Round {history.at(-1)!.id}</text></svg></div>;
}
