import { describe, expect, it, beforeEach } from 'vitest';
import worker, { type Env } from './index.ts';

class FakeKV implements Pick<KVNamespace, 'get' | 'put' | 'list' | 'delete'> {
  private readonly store = new Map<string, { value: string; expiresAt: number }>();

  async get(key: string): Promise<string | null> {
    const entry = this.store.get(key);
    if (!entry) return null;
    if (entry.expiresAt < Date.now()) {
      this.store.delete(key);
      return null;
    }
    return entry.value;
  }

  async put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void> {
    const ttl = options?.expirationTtl ?? 60;
    this.store.set(key, { value, expiresAt: Date.now() + ttl * 1000 });
  }

  async delete(key: string): Promise<void> {
    this.store.delete(key);
  }

  async list(options?: {
    prefix?: string;
    limit?: number;
  }): Promise<KVNamespaceListResult<unknown, string>> {
    const prefix = options?.prefix ?? '';
    const keys = [...this.store.keys()]
      .filter((k) => k.startsWith(prefix))
      .slice(0, options?.limit ?? 1000)
      .map((name) => ({ name }));
    return { keys, list_complete: true, cursor: '' } as KVNamespaceListResult<unknown, string>;
  }
}

function makeEnv(): Env {
  return {
    LOBBY_CODES: new FakeKV() as unknown as KVNamespace,
    ROOM_WORKER: 'test-room',
    ENV: 'test',
  };
}

async function call(env: Env, method: string, path: string, body?: unknown): Promise<Response> {
  return worker.fetch(
    new Request(`https://x.test${path}`, {
      method,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      headers: body !== undefined ? { 'content-type': 'application/json' } : {},
    }),
    env,
  );
}

describe('matchmaker', () => {
  let env: Env;
  beforeEach(() => {
    env = makeEnv();
  });

  it('creates a private lobby with a code and returns ws url', async () => {
    const res = await call(env, 'POST', '/lobby', { topology: 'torus' });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { code: string; roomId: string; wsUrl: string };
    expect(body.code).toMatch(/^[BCDFGHJKLMNPQRSTVWXYZ23456789]{6}$/);
    expect(body.wsUrl).toContain('test-room');
  });

  it('rejects invalid topology', async () => {
    const res = await call(env, 'POST', '/lobby', { topology: 'sphere-2' });
    expect(res.status).toBe(400);
  });

  it('joins by code', async () => {
    const created = await call(env, 'POST', '/lobby', { topology: 'plane' });
    const { code, roomId } = (await created.json()) as { code: string; roomId: string };
    const res = await call(env, 'POST', `/lobby/${code}/join`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { roomId: string };
    expect(body.roomId).toBe(roomId);
  });

  it('returns 404 for unknown code', async () => {
    const res = await call(env, 'POST', '/lobby/UNKNOWN/join');
    expect(res.status).toBe(404);
  });

  it('reuses an existing open room when capacity remains', async () => {
    const first = await call(env, 'POST', '/open/join');
    const second = await call(env, 'POST', '/open/join');
    const a = (await first.json()) as { roomId: string };
    const b = (await second.json()) as { roomId: string };
    expect(b.roomId).toBe(a.roomId);
  });

  it('healthz returns ok', async () => {
    const res = await call(env, 'GET', '/healthz');
    const body = (await res.json()) as { ok: boolean };
    expect(body.ok).toBe(true);
  });
});
