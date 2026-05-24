import { describe, expect, it } from 'vitest';

describe('room worker module', () => {
  it('loads worker entry without throwing', async () => {
    const mod = await import('./worker.ts');
    expect(typeof mod.default.fetch).toBe('function');
    expect(mod.Room).toBeTypeOf('function');
  });
});
