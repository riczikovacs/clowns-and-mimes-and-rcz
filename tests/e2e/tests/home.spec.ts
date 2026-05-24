import { test, expect } from '@playwright/test';

test('home page advertises the game and shows downloads', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Clowns and Mimes');
  await expect(page.getByRole('link', { name: 'Windows' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'macOS' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Linux' })).toBeVisible();
});

test('how to play section is reachable on mobile', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'How to play' })).toBeVisible();
});
