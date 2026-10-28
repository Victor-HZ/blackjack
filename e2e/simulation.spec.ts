import { expect, test } from '@playwright/test';
import type { Page } from '@playwright/test';
import { DEFAULT_RULES, score } from '../src/lib/blackjack';
import { createSimulation, SIMULATION_STORAGE_KEY, simulationReducer } from '../src/lib/simulation';
import type { SimulationMode, SimulationStore } from '../src/lib/simulation';

const freePlayKey = 'blackjack-studio:v1';
const simulation = (page: Page) => page.getByTestId('simulation');

async function openSimulation(page: Page) {
  const entry = page.getByRole('navigation', { name: 'Main navigation' }).getByRole('button', { name: 'Simulation', exact: true });
  const menu = page.getByRole('button', { name: 'Open navigation' });
  if (await menu.isVisible()) await menu.click();
  await entry.click();
  await expect(simulation(page)).toBeVisible();
}

async function readStore(page: Page): Promise<SimulationStore> {
  return page.evaluate(key => JSON.parse(localStorage.getItem(key)!), SIMULATION_STORAGE_KEY);
}

// Seed a valid, unstarted session whose first hand is a hard total below 12.
// Standing is unambiguously wrong, so the feedback/retry assertion never depends on luck.
async function prepareLowHand(page: Page, mode: SimulationMode) {
  for (let seed = 0; seed < 1000; seed += 1) {
    const active = createSimulation({ rounds: 10, mode, countChecks: true }, { seed, id: `browser-${mode}`, createdAt: '2026-10-28T00:00:00.000Z' });
    const dealt = simulationReducer(active, { type: 'deal' });
    if (dealt.stage === 'playing' && dealt.game.phase === 'playing' && score(dealt.game.hands[0].cards).total < 12) {
      await page.addInitScript(({ key, value }) => {
        if (!localStorage.getItem(key)) localStorage.setItem(key, JSON.stringify(value));
      }, { key: SIMULATION_STORAGE_KEY, value: { version: 1, active, history: [] } });
      return;
    }
  }
  throw new Error('Could not find the deterministic low-hand fixture.');
}

const errors = new WeakMap<Page, string[]>();
test.beforeEach(async ({ page }) => {
  const messages: string[] = [];
  errors.set(page, messages);
  page.on('pageerror', error => messages.push(error.message));
  page.on('console', message => { if (message.type() === 'error') messages.push(message.text()); });
});
test.afterEach(async ({ page }) => expect(errors.get(page), 'No browser application errors').toEqual([]));

test('ten-round test gates every count, ends exactly, and closes the learning loop without changing the original score', async ({ page }) => {
  test.setTimeout(60_000);
  await prepareLowHand(page, 'test');
  await page.goto('/');
  await expect(page.getByRole('button', { name: 'Deal a hand', exact: true })).toBeVisible();
  const originalFreePlay = await page.evaluate(key => localStorage.getItem(key), freePlayKey);
  await openSimulation(page);
  const view = simulation(page);
  for (let round = 1; round <= 10; round += 1) {
    await expect(page.getByTestId('simulation-round')).toHaveText(`Round ${round} of 10`);
    await page.getByTestId('simulation-deal').click();
    if (await view.getByRole('button', { name: 'No insurance', exact: true }).isVisible()) {
      await view.getByRole('button', { name: 'No insurance', exact: true }).click();
    }
    if (await view.getByRole('button', { name: 'Stand', exact: true }).isVisible()) {
      await view.getByRole('button', { name: 'Stand', exact: true }).click();
    }
    await expect(page.getByTestId('simulation-feedback')).toHaveCount(0);
    await expect(page.getByTestId('simulation-results')).toHaveCount(0);
    await expect(view.getByRole('button', { name: 'Check my count', exact: true })).toBeVisible();
    await expect(page.getByTestId('simulation-next-round')).toHaveCount(0);
    await view.getByRole('button', { name: 'Check my count', exact: true }).click();
    await expect(view.getByRole('region', { name: 'Simulation table' })).toHaveCount(0);
    await expect(view.locator('.sim-card')).toHaveCount(0);
    await expect(page.getByTestId('simulation-submit-count')).toBeDisabled();
    await expect(page.getByTestId('simulation-next-round')).toHaveCount(0);
    await page.getByTestId('simulation-count').fill('-416');
    await page.getByTestId('simulation-submit-count').click();
    await expect(view.getByRole('heading', { name: 'Count saved', exact: true })).toBeVisible();
    await expect(view.getByText(/Correct count/)).toHaveCount(0);
    await expect(page.getByTestId('simulation-count')).toHaveCount(0);
    await expect(page.getByTestId('simulation-submit-count')).toHaveCount(0);
    await page.getByTestId('simulation-next-round').click();
  }
  const results = page.getByTestId('simulation-results');
  await expect(results.getByRole('heading', { name: 'Session complete', exact: true })).toBeVisible();
  await expect(results).toContainText('10 rounds · Test');
  await expect(results).toContainText('0 of 10 checks');
  await expect(page.getByTestId('simulation-deal')).toHaveCount(0);
  await expect(page.getByTestId('simulation-next-round')).toHaveCount(0);
  await expect.poll(async () => (await readStore(page)).history.length).toBe(1);
  const finished = await readStore(page);
  expect(finished.active?.completedRounds).toBe(10);
  expect(finished.active?.game.rounds).toBe(10);
  expect(finished.active?.counts).toHaveLength(10);
  expect(finished.history[0].id).toBe(finished.active?.id);
  expect(await page.evaluate(key => localStorage.getItem(key), freePlayKey)).toBe(originalFreePlay);

  const review = results.getByRole('region', { name: 'Retry a missed decision' });
  await expect(review).toBeVisible();
  await review.getByRole('button', { name: 'Stand', exact: true }).click();
  await expect(review.getByRole('status')).toContainText('Recommended:');
  await expect(review.getByRole('status')).toContainText('Review answers do not change your session score.');
  await expect(review.getByRole('button', { name: 'Stand', exact: true })).toBeDisabled();
  expect((await readStore(page)).history).toEqual(finished.history);
  await results.getByRole('button', { name: 'Practice card counting', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Keep your eye on the count.', exact: true })).toBeVisible();
  await openSimulation(page);
  await expect(page.getByTestId('simulation-results')).toBeVisible();
  await page.getByRole('button', { name: 'Repeat 10 rounds', exact: true }).click();
  await expect(page.getByTestId('simulation-round')).toHaveText('Round 1 of 10');
  await expect.poll(async () => (await readStore(page)).active?.id).not.toBe(finished.active?.id);
  expect((await readStore(page)).history).toEqual(finished.history);
});

test('guided feedback survives leaving and reload, then enforces count submission and explicit discard', async ({ page }) => {
  await prepareLowHand(page, 'guided');
  await page.goto('/');
  await openSimulation(page);
  const view = simulation(page);
  await page.getByTestId('simulation-deal').click();
  await expect(view.locator('.sim-dealer').getByRole('img', { name: 'Face-down card', exact: true })).toHaveCount(1);
  await view.getByRole('button', { name: 'Stand', exact: true }).click();
  await expect(page.getByTestId('simulation-feedback')).toContainText('Recommended:');
  await expect(view.getByRole('button', { name: 'Stand', exact: true })).toHaveCount(0);
  await expect(page.getByTestId('simulation-next-round')).toHaveCount(0);
  const pending = (await readStore(page)).active!;
  expect(pending.decisions).toHaveLength(1);
  expect(pending.decisions[0].correct).toBe(false);
  await view.getByRole('button', { name: 'Save & leave', exact: true }).click();
  await openSimulation(page);
  await expect(page.getByTestId('simulation-feedback')).toContainText('Recommended:');
  await page.reload();
  await openSimulation(page);
  await expect(page.getByTestId('simulation-feedback')).toContainText('Recommended:');
  expect((await readStore(page)).active).toEqual(pending);
  await page.getByTestId('simulation-continue').click();
  await view.getByRole('button', { name: 'Check my count', exact: true }).click();
  await expect(view.locator('.sim-card')).toHaveCount(0);
  await expect(page.getByTestId('simulation-next-round')).toHaveCount(0);
  await page.getByTestId('simulation-count').fill('1.5');
  await expect(page.getByTestId('simulation-submit-count')).toBeDisabled();
  await page.getByTestId('simulation-count').fill('-416');
  await page.getByTestId('simulation-submit-count').click();
  await expect(view.getByRole('heading', { name: /^Correct count:/ })).toBeVisible();
  expect((await readStore(page)).active?.counts).toHaveLength(1);
  await view.getByRole('button', { name: 'End session', exact: true }).click();
  await view.getByRole('alertdialog').getByRole('button', { name: 'Keep practicing', exact: true }).click();
  await expect(page.getByTestId('simulation-next-round')).toBeVisible();
  await view.getByRole('button', { name: 'End session', exact: true }).click();
  await view.getByRole('alertdialog').getByRole('button', { name: 'Discard session', exact: true }).click();
  await expect(view.getByRole('heading', { name: 'Set up a simulation', exact: true })).toBeVisible();
  expect((await readStore(page)).active).toBeNull();
  expect((await readStore(page)).history).toEqual([]);
});

test('reviewing a saved simulation uses its rules while preserving the free-play table', async ({ page }) => {
  let completed = createSimulation({ rounds: 10, mode: 'test', countChecks: false, rules: { ...DEFAULT_RULES, hitSoft17: true } }, { seed: 1234, id: 'saved-h17', createdAt: '2026-10-28T00:00:00.000Z' });
  for (let step = 0; step < 100 && completed.stage !== 'complete'; step += 1) {
    if (completed.stage === 'ready') completed = simulationReducer(completed, { type: 'deal' });
    else if (completed.stage === 'playing') completed = simulationReducer(completed, { type: 'play', choice: completed.game.phase === 'insurance' ? 'insurance' : 'stand' });
    else if (completed.stage === 'roundReview') completed = simulationReducer(completed, { type: 'finishRound', at: '2026-10-28T00:15:00.000Z' });
  }
  expect(completed.stage).toBe('complete');
  expect(completed.decisions.some(decision => !decision.correct)).toBe(true);
  await page.addInitScript(({ key, value }) => localStorage.setItem(key, JSON.stringify(value)), {
    key: SIMULATION_STORAGE_KEY, value: { version: 1, active: null, history: [completed] },
  });
  await page.goto('/');
  await expect(page.getByRole('button', { name: 'Deal a hand', exact: true })).toBeVisible();
  const originalFreePlay = await page.evaluate(key => localStorage.getItem(key), freePlayKey);
  await openSimulation(page);
  await simulation(page).getByRole('button', { name: /10 rounds · Test/ }).click();
  await page.getByTestId('simulation-results').getByRole('button', { name: 'Open strategy guide', exact: true }).click();
  await expect(page.locator('.strategy-rule-card')).toContainText('Hits');
  await page.getByLabel('Your first card').selectOption('A');
  await page.getByLabel('Your second card').selectOption('8');
  await page.getByLabel('Dealer’s upcard').selectOption('6');
  await expect(page.locator('.strategy-answer')).toContainText('Double');
  await page.getByRole('navigation', { name: 'Main navigation' }).getByRole('button', { name: 'Practice table', exact: true }).click();
  await expect(page.locator('.table-heading')).toContainText('Dealer stands on 17');
  expect(await page.evaluate(key => localStorage.getItem(key), freePlayKey)).toBe(originalFreePlay);
  await page.getByRole('navigation', { name: 'Main navigation' }).getByRole('button', { name: 'Strategy guide', exact: true }).click();
  await expect(page.locator('.strategy-rule-card')).toContainText('Stands');
});

for (const colorScheme of ['light', 'dark'] as const) {
  test(`mobile simulation setup and play adapt to ${colorScheme} system appearance`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.emulateMedia({ colorScheme, reducedMotion: 'reduce' });
    await page.goto('/');
    await openSimulation(page);
    const view = simulation(page);
    await expect(view).toHaveCSS('background-color', colorScheme === 'dark' ? 'rgb(0, 0, 0)' : 'rgb(242, 242, 247)');
    await view.getByText('25 rounds', { exact: true }).click();
    await expect(view.getByRole('radio', { name: '25 rounds', exact: true })).toBeChecked();
    await view.getByRole('radio', { name: /^Test/ }).check();
    await view.getByRole('checkbox', { name: 'Check running count after each round', exact: true }).uncheck();
    await view.getByRole('button', { name: 'Start simulation', exact: true }).click();
    await expect(page.getByTestId('simulation-round')).toHaveText('Round 1 of 25');
    await page.getByTestId('simulation-deal').click();
    await expect(view.getByRole('region', { name: 'Simulation table' })).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    const saved = (await readStore(page)).active;
    await page.emulateMedia({ colorScheme: colorScheme === 'light' ? 'dark' : 'light' });
    await expect(view).toHaveCSS('background-color', colorScheme === 'light' ? 'rgb(0, 0, 0)' : 'rgb(242, 242, 247)');
    expect((await readStore(page)).active).toEqual(saved);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  });
}
