import { describe, expect, it } from 'vitest';

describe('matchmaker module', () => {
  it('loads without throwing', async () => {
    const mod = await import('./index.ts');
    expect(typeof mod.default.fetch).toBe('function');
  });
});
