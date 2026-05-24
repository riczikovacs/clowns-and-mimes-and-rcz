import { defineConfig, devices } from '@playwright/test';

const isCI = !!process.env.CI;

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: isCI,
  retries: isCI ? 1 : 0,
  workers: isCI ? 2 : undefined,
  reporter: isCI ? [['github'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: process.env.WEBSITE_URL ?? 'http://localhost:4321/clowns-and-mimes/',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: devices['Desktop Chrome'] },
    { name: 'firefox', use: devices['Desktop Firefox'] },
    { name: 'mobile-safari', use: devices['iPhone 13'] },
  ],
  webServer: {
    command: isCI
      ? 'pnpm --filter website preview --port 4321 --host 127.0.0.1'
      : 'pnpm --filter website dev',
    url: 'http://localhost:4321/clowns-and-mimes/',
    reuseExistingServer: !isCI,
    timeout: 60_000,
    cwd: '../..',
  },
});
