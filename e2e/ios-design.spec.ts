import { expect, test } from '@playwright/test';
import type { Page } from '@playwright/test';

const preview = '/ios/Design/preview.html';
const phone = (page: Page, index: number) => page.locator(`[data-phone="${index}"]`);

for (const width of [1440, 390]) {
  test(`iOS preview follows live system appearance without losing a session at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 1000 });
    await page.emulateMedia({ colorScheme: 'light' });
    await page.goto(preview);
    await expect(page.getByRole('radio', { name: 'System', exact: true })).toBeChecked();
    await expect(phone(page, 0)).toHaveCSS('background-color', 'rgb(242, 242, 247)');

    const drill = phone(page, 1);
    await drill.getByRole('button', { name: 'Answer 1', exact: true }).click();
    await expect(drill.getByRole('status')).toContainText('Correct');
    await page.emulateMedia({ colorScheme: 'dark' });
    await expect(phone(page, 0)).toHaveCSS('background-color', 'rgb(0, 0, 0)');
    await expect(page.locator('html')).toHaveCSS('color-scheme', 'dark');
    await expect(drill.getByRole('status')).toContainText('Correct');
    await expect(drill.locator('.drill-meta')).toHaveText('1 of 151 correct');
    await expect(drill.locator('.playing-card')).toHaveCSS('background-color', 'rgb(250, 249, 240)');

    await drill.getByRole('button', { name: 'Next', exact: true }).click();
    await expect(drill.getByRole('img', { name: 'K of hearts' })).toBeVisible();
    await page.emulateMedia({ colorScheme: 'light' });
    await expect(phone(page, 0)).toHaveCSS('background-color', 'rgb(242, 242, 247)');
    await expect(drill.locator('.drill-meta')).toHaveText('2 of 151 correct');
    await expect(drill.getByRole('img', { name: 'K of hearts' })).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  });
}

test('iOS preview manual appearance remains selected until System is restored', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto(preview);
  await expect(phone(page, 0)).toHaveCSS('background-color', 'rgb(0, 0, 0)');
  await page.getByText('Light', { exact: true }).click();
  await expect(page.getByRole('radio', { name: 'Light', exact: true })).toBeChecked();
  await expect(phone(page, 0)).toHaveCSS('background-color', 'rgb(242, 242, 247)');
  await page.emulateMedia({ colorScheme: 'light' });
  await page.emulateMedia({ colorScheme: 'dark' });
  await expect(phone(page, 0)).toHaveCSS('background-color', 'rgb(242, 242, 247)');

  await page.getByText('Dark', { exact: true }).click();
  await page.emulateMedia({ colorScheme: 'light' });
  await expect(phone(page, 0)).toHaveCSS('background-color', 'rgb(0, 0, 0)');
  await page.getByText('System', { exact: true }).click();
  await expect(page.getByRole('radio', { name: 'System', exact: true })).toBeChecked();
  await expect(phone(page, 0)).toHaveCSS('background-color', 'rgb(242, 242, 247)');
  await page.emulateMedia({ colorScheme: 'dark' });
  await expect(phone(page, 0)).toHaveCSS('background-color', 'rgb(0, 0, 0)');
});

for (const colorScheme of ['light', 'dark'] as const) {
  test(`iOS preview primary actions retain WCAG text contrast in ${colorScheme} mode`, async ({ page }) => {
    await page.emulateMedia({ colorScheme });
    await page.goto(preview);
    const contrast = await page.locator('.primary').evaluateAll(elements => {
      function luminance(color: string) {
        const rgb = color.match(/\d+(?:\.\d+)?/g)!.slice(0, 3).map(Number).map(value => {
          const channel = value / 255;
          return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
        });
        return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722;
      }
      return elements.map(element => {
        const style = getComputedStyle(element);
        const foreground = luminance(style.color);
        const background = luminance(style.backgroundColor);
        return (Math.max(foreground, background) + 0.05) / (Math.min(foreground, background) + 0.05);
      });
    });
    expect(contrast.length).toBeGreaterThanOrEqual(2);
    contrast.forEach(ratio => expect(ratio).toBeGreaterThanOrEqual(4.5));
    await expect(phone(page, 0).locator('.session-card')).toHaveCSS('background-color', colorScheme === 'dark' ? 'rgb(28, 28, 30)' : 'rgb(255, 255, 255)');
  });
}

test('iOS preview completes a scored drill, pauses, restarts, and navigates screens', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(preview);
  const practice = phone(page, 0);
  await practice.getByRole('button', { name: 'Start session', exact: true }).click();
  await practice.getByRole('button', { name: 'Pause drill', exact: true }).click();
  await expect(practice.getByRole('heading', { name: 'Paused', exact: true })).toBeVisible();
  await expect(practice.locator('[data-answer]')).toHaveCount(0);
  await practice.getByRole('button', { name: 'Resume', exact: true }).click();

  for (let index = 0; index < 15; index += 1) {
    const rank = (await practice.locator('.playing-card').getAttribute('aria-label'))!.split(' of ')[0];
    const correct = ['2', '3', '4', '5', '6'].includes(rank) ? 1 : ['10', 'J', 'Q', 'K', 'A'].includes(rank) ? -1 : 0;
    const answer = index === 0 ? 0 : correct;
    await practice.getByRole('button', { name: `Answer ${answer}`, exact: true }).click();
    await expect(practice.getByRole('status')).toContainText(index === 0 ? 'Correct value: +1' : 'Correct');
    await expect(practice.locator('[data-answer]')).toHaveCount(0);
    await practice.getByRole('button', { name: index === 14 ? 'See results' : 'Next', exact: true }).click();
  }
  await expect(practice.getByRole('heading', { name: 'Session complete' })).toBeVisible();
  await expect(practice.locator('.result-metrics')).toContainText('93%');
  await expect(practice.locator('.result-metrics')).toContainText('14/15');
  await practice.getByRole('button', { name: 'Practice again' }).click();
  await expect(practice.locator('.drill-meta')).toHaveText('1 of 150 correct');
  await practice.getByRole('button', { name: 'Close prototype drill' }).click();

  await practice.getByRole('button', { name: 'Learn', exact: true }).click();
  await expect(practice.getByRole('heading', { name: 'Lessons', exact: true })).toBeVisible();
  await practice.getByRole('button', { name: 'Table', exact: true }).click();
  await expect(practice.getByRole('img', { name: 'Face-down card' })).toBeVisible();
  await practice.getByRole('button', { name: 'Progress', exact: true }).click();
  await expect(practice.locator('.result-metrics')).toContainText('92%');
  await practice.getByRole('button', { name: 'Train', exact: true }).click();
  await practice.getByRole('button', { name: 'Pair cancellation 1 min', exact: true }).click();
  await expect(practice.getByRole('heading', { name: 'Blackjack Studio Pro' })).toBeVisible();
  await practice.getByRole('button', { name: 'Unlock Pro · $19.99' }).click();
  await expect(page.locator('#toast')).toContainText('no purchase is made');
  expect(errors).toEqual([]);
});

test('iOS preview works offline and respects reduced motion at a narrow width', async ({ page, context }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ colorScheme: 'dark', reducedMotion: 'reduce' });
  await page.goto(preview);
  await context.setOffline(true);
  await page.getByText('Light', { exact: true }).click();
  const practice = phone(page, 0);
  await practice.getByRole('button', { name: 'Learn', exact: true }).click();
  await practice.getByRole('button', { name: 'Lesson 1, Three small numbers, completed', exact: true }).click();
  await practice.getByRole('button', { name: 'Try a card', exact: true }).click();
  await practice.getByRole('button', { name: 'Answer 1', exact: true }).click();
  await expect(practice.getByRole('status')).toContainText('Correct');
  await expect(page.locator('#toast')).toHaveCSS('transition-duration', '0s');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await expect(page.getByText('A design review, not App Store screenshots.', { exact: true })).toBeAttached();
});
