import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { createGame } from '../src/lib/blackjack';
import type { Card } from '../src/lib/blackjack';

const storageKey = 'blackjack-studio:v1';
const card = (rank: Card['rank'], suit: Card['suit'] = '♠'): Card => ({ rank, suit });
async function prepareTable(page: Page, prefix: Card[] = [card('10'), card('6','♦'), card('8'), card('9','♥'), card('10','♣')]) {
  const game = createGame({ seed: 1234 });
  game.shoe = [...prefix, ...game.shoe.slice(prefix.length)];
  await page.addInitScript(({ key, value }) => {
    if (!localStorage.getItem(key)) localStorage.setItem(key, JSON.stringify(value));
  }, { key: storageKey, value: { version: 1, game, stats: { decisions: 0, correct: 0, drills: 0, correctDrills: 0 }, showHints: true, showCount: true, bet: 25 } });
}

const pageErrors = new WeakMap<Page, string[]>();
test.beforeEach(async ({ page }) => {
  const errors: string[] = [];
  pageErrors.set(page, errors);
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
});
test.afterEach(async ({ page }) => {
  expect(pageErrors.get(page), 'No unhandled browser errors').toEqual([]);
});

test('deals a real hand, hides the hole card, settles the wager, and persists progress', async ({ page }) => {
  await prepareTable(page);
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Make your next move better.' })).toBeVisible();
  await page.getByRole('button', { name: 'Deal a hand', exact: true }).click();
  await expect(page.locator('.dealer-zone').getByLabel('Face-down card')).toHaveCount(1);
  await expect(page.locator('.dealer-zone').getByLabel('9 of hearts')).toHaveCount(0);
  await expect(page.locator('.stat-card').filter({ hasText: 'Practice bankroll' })).toContainText('975');
  await expect(page.getByRole('heading', { name: 'Stand is the move.' })).toBeVisible();
  await page.getByRole('button', { name: /^Stand/ }).click();
  await expect(page.locator('.round-result')).toContainText('You won 25 credits.');
  await expect(page.locator('.dealer-zone').getByLabel('9 of hearts')).toBeVisible();
  await expect(page.locator('.stat-card').filter({ hasText: 'Practice bankroll' })).toContainText('1,025');
  await page.reload();
  await expect(page.locator('.round-result')).toContainText('You won 25 credits.');
  await page.getByRole('button', { name: 'Your progress', exact: true }).click();
  await expect(page.getByRole('row').filter({ hasText: '#1' })).toContainText('win');
  await expect(page.locator('.stat-card').filter({ hasText: 'Strategy accuracy' })).toContainText('100%');
  const downloadEvent = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export CSV' }).click();
  expect((await downloadEvent).suggestedFilename()).toBe('blackjack-practice.csv');
});

test('supports an unassisted hand and valid keyboard actions without showing hints', async ({ page }) => {
  await prepareTable(page);
  await page.goto('/');
  await page.getByRole('switch', { name: 'Show strategy hints' }).click();
  await page.getByRole('switch', { name: 'Show card count' }).click();
  await page.getByRole('button', { name: 'Deal a hand', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'You’ve got this.' })).toBeVisible();
  await expect(page.locator('.recommended-move')).toHaveCount(0);
  await expect(page.locator('.count-values')).toContainText('••');
  await page.keyboard.press('s');
  await expect(page.locator('.round-result')).toContainText('You won 25 credits.');
  await page.getByRole('switch', { name: 'Show strategy hints' }).click();
  await expect(page.getByRole('status').filter({ hasText: 'Good decision.' })).toBeVisible();
  await expect(page.getByRole('switch', { name: 'Show strategy hints' })).toBeChecked();
});

test('splits a pair into playable hands with separate wagers and settlement', async ({ page }) => {
  await prepareTable(page, [card('8'),card('6','♦'),card('8','♥'),card('10','♣'),card('3'),card('2'),card('10'),card('10'),card('10')]);
  await page.goto('/');
  await page.getByRole('button', { name: 'Deal a hand', exact: true }).click();
  await page.getByRole('button', { name: /^Split/ }).click();
  await expect(page.locator('.hand-group')).toHaveCount(2);
  await expect(page.locator('.stat-card').filter({ hasText: 'Practice bankroll' })).toContainText('950');
  await page.getByRole('button', { name: /^Double/ }).click();
  await expect(page.locator('.active-hand')).toContainText('HAND 2');
  await page.getByRole('button', { name: /^Double/ }).click();
  await expect(page.locator('.round-result')).toContainText('You won 100 credits.');
  await expect(page.locator('.stat-card').filter({ hasText: 'Practice bankroll' })).toContainText('1,100');
});

test('strategy chart tabs and hand lookup produce rule-aware advice', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Strategy guide', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Build a better instinct.' })).toBeVisible();
  await page.getByRole('tab', { name: 'Soft totals' }).click();
  await expect(page.getByRole('tab', { name: 'Soft totals' })).toHaveAttribute('aria-selected','true');
  await expect(page.getByRole('rowheader', { name: 'A, 7', exact: true })).toBeVisible();
  await page.getByRole('tab', { name: 'Pairs' }).click();
  await expect(page.getByRole('rowheader', { name: '8, 8', exact: true })).toBeVisible();
  await page.getByLabel('Your first card').selectOption('8');
  await page.getByLabel('Your second card').selectOption('8');
  await page.getByLabel('Dealer’s upcard').selectOption('6');
  await expect(page.locator('.strategy-answer')).toContainText('Split');
  await page.getByLabel('Your first card').selectOption('10');
  await page.getByLabel('Your second card').selectOption('6');
  await page.getByLabel('Dealer’s upcard').selectOption('10');
  await expect(page.locator('.strategy-answer')).toContainText('Surrender');
});

test('counts displayed cards, records accuracy once, and starts the next challenge', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Card counting', exact: true }).click();
  const label = await page.locator('.counting-current-card .counting-card').getAttribute('aria-label');
  const rank = label!.split(' of ')[0];
  const answer = ['2','3','4','5','6'].includes(rank) ? 1 : ['10','J','Q','K','A'].includes(rank) ? -1 : 0;
  await page.getByRole('spinbutton', { name: 'What’s the running count?' }).fill(String(answer));
  await page.getByRole('button', { name: 'Check count' }).click();
  await expect(page.getByRole('status')).toContainText('That’s right!');
  await expect(page.getByRole('button', { name: 'Check count' })).toBeDisabled();
  await expect(page.getByRole('progressbar')).toHaveAttribute('aria-valuenow','1');
  await page.getByRole('button', { name: 'Next card' }).click();
  await expect(page.locator('.counting-progress-heading')).toContainText('Card 2 of 20');
  await page.getByRole('button', { name: 'Your progress', exact: true }).click();
  await expect(page.locator('.stat-card').filter({ hasText: 'Counting accuracy' })).toContainText('100%');
  await expect(page.locator('.stat-card').filter({ hasText: 'Counting accuracy' })).toContainText('1 correct of 1 checks');
});

test('prevents changing a live round, then applies settings while preserving results', async ({ page }) => {
  await prepareTable(page);
  await page.goto('/');
  await page.getByRole('button', { name: 'Deal a hand', exact: true }).click();
  await page.getByRole('button', { name: 'Table settings', exact: true }).first().click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByRole('button', { name: 'Save table settings' })).toBeDisabled();
  await expect(dialog).toContainText('Finish the current hand');
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
  await page.getByRole('button', { name: /^Stand/ }).click();
  await page.getByRole('button', { name: 'Table settings', exact: true }).first().click();
  await dialog.getByLabel('Number of decks').focus();
  await dialog.getByLabel('Number of decks').selectOption('8');
  await expect(dialog.getByLabel('Number of decks')).toBeFocused();
  await dialog.getByRole('switch', { name: 'Dealer hits soft 17' }).click();
  await dialog.getByRole('switch', { name: 'Late surrender' }).click();
  await dialog.getByRole('button', { name: 'Save table settings' }).click();
  await expect(page.locator('.table-heading')).toContainText('8 decks');
  await expect(page.locator('.table-heading')).toContainText('Dealer hits soft 17');
  await expect(page.locator('.stat-card').filter({ hasText: 'Practice bankroll' })).toContainText('1,025');
  await page.getByRole('button', { name: 'Strategy guide', exact: true }).click();
  await expect(page.locator('.strategy-rule-card')).toContainText('Not allowed');
  await expect(page.locator('.strategy-answer')).toContainText('Hit');
});

test('invalid saved history or active-round state safely starts a fresh session', async ({ page }) => {
  await page.goto('/');
  const base = { version: 1, game: createGame({ seed: 987 }), stats: { decisions: 0, correct: 0, drills: 0, correctDrills: 0 }, showHints: true, showCount: true, bet: 25 };
  const corruptions = [
    { ...base, game: { ...base.game, bankroll: 750, rounds: 1, history: [null] } },
    { ...base, game: { ...base.game, bankroll: 750, phase: 'playing', activeHand: 3, hands: [], dealer: [] } },
  ];
  for (const value of corruptions) {
    await page.evaluate(({ key, saved }) => localStorage.setItem(key, JSON.stringify(saved)), { key: storageKey, saved: value });
    await page.reload();
    await expect(page.getByRole('heading', { name: 'Make your next move better.' })).toBeVisible();
    await expect(page.locator('.stat-card').filter({ hasText: 'Practice bankroll' })).toContainText('1,000');
    await expect(page.getByRole('button', { name: 'Deal a hand', exact: true })).toBeEnabled();
    expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)!).game.rounds, storageKey)).toBe(0);
    expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)!).game.history, storageKey)).toEqual([]);
  }
});

test('clearing a draft wager preserves completed rounds and bankroll after reload', async ({ page }) => {
  await prepareTable(page);
  await page.goto('/');
  await page.getByRole('button', { name: 'Deal a hand', exact: true }).click();
  await page.getByRole('button', { name: /^Stand/ }).click();
  await expect(page.locator('.round-result')).toContainText('You won 25 credits.');
  await page.getByRole('spinbutton', { name: 'Custom bet' }).fill('');
  await expect(page.getByRole('button', { name: 'Deal next hand', exact: true })).toBeDisabled();
  await page.reload();
  await expect(page.locator('.stat-card').filter({ hasText: 'Practice bankroll' })).toContainText('1,025');
  await expect(page.locator('.round-result')).toContainText('You won 25 credits.');
  await expect(page.getByRole('spinbutton', { name: 'Custom bet' })).toHaveValue('');
  await expect(page.getByRole('button', { name: 'Deal next hand', exact: true })).toBeDisabled();
  await page.getByRole('spinbutton', { name: 'Custom bet' }).fill('25');
  await expect(page.getByRole('button', { name: 'Deal next hand', exact: true })).toBeEnabled();
  await page.getByRole('button', { name: 'Your progress', exact: true }).click();
  await expect(page.getByRole('row').filter({ hasText: '#1' })).toContainText('win');
  await expect(page.locator('.stat-card').filter({ hasText: 'Strategy accuracy' })).toContainText('100%');
});

test('desktop table fits the viewport and renders without application errors', async ({ page }) => {
  await prepareTable(page);
  await page.goto('/');
  await page.getByRole('button', { name: 'Deal a hand', exact: true }).click();
  await expect(page.locator('.game-panel')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await page.screenshot({ path: '/tmp/blackjack-desktop.png', fullPage: true });
});

test.describe('mobile layout', () => {
  test.use({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  test('navigates, plays a hand, and keeps all screens within the viewport', async ({ page }) => {
    await prepareTable(page);
    await page.goto('/');
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    await page.getByRole('button', { name: 'Deal a hand', exact: true }).click();
    await page.getByRole('button', { name: /^Stand/ }).click();
    await expect(page.locator('.round-result')).toContainText('You won 25 credits.');
    await page.screenshot({ path: '/tmp/blackjack-mobile.png', fullPage: true });
    for (const name of ['Strategy guide','Card counting','Your progress']) {
      await page.getByRole('button', { name: 'Open navigation' }).click();
      await page.getByRole('navigation', { name: 'Main navigation' }).getByRole('button', { name, exact: true }).click();
      await expect(page.locator('.sidebar-scrim')).toHaveCount(0);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), `${name} has no horizontal viewport overflow`).toBe(true);
    }
  });
});
