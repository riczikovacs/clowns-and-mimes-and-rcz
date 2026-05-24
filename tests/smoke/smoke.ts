// One-shot end-to-end check of a deployed matchmaker + room. Hits /healthz,
// creates a private lobby, joins by code, then opens the returned WebSocket
// and verifies the room responds with a snapshot. Exits non-zero on any
// failure so CI or a pnpm hook can rely on it.

import { WebSocket } from 'ws';

const PROTOCOL_VERSION = 1;
const WS_TIMEOUT_MS = 8000;

async function main(): Promise<void> {
  const base = process.argv[2];
  if (!base) {
    console.error('usage: smoke.ts <matchmaker-url>');
    process.exit(2);
  }
  console.log(`[smoke] base=${base}`);

  await check('healthz', async () => {
    const res = await fetch(`${base}/healthz`);
    if (!res.ok) throw new Error(`status ${res.status}`);
    const body = (await res.json()) as { ok?: boolean };
    if (body.ok !== true) throw new Error(`body=${JSON.stringify(body)}`);
  });

  const created = await check('create lobby', async () => {
    const res = await fetch(`${base}/lobby`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ topology: 'plane' }),
    });
    if (!res.ok) throw new Error(`status ${res.status}`);
    const body = (await res.json()) as { code: string; roomId: string; wsUrl: string };
    if (!body.code || !body.roomId || !body.wsUrl)
      throw new Error(`missing fields: ${JSON.stringify(body)}`);
    return body;
  });

  await check('join by code', async () => {
    const res = await fetch(`${base}/lobby/${created.code}/join`, { method: 'POST' });
    if (!res.ok) throw new Error(`status ${res.status}`);
    const body = (await res.json()) as { roomId: string; wsUrl: string };
    if (body.roomId !== created.roomId) throw new Error(`roomId mismatch`);
  });

  await check('ws join + snapshot', async () => {
    const ws = new WebSocket(created.wsUrl);
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => {
        ws.close();
        reject(new Error('ws timed out before snapshot'));
      }, WS_TIMEOUT_MS);
      ws.on('open', () => {
        ws.send(JSON.stringify({ t: 'join', v: PROTOCOL_VERSION, name: 'smoke' }));
      });
      ws.on('message', (data: Buffer | string) => {
        const text = typeof data === 'string' ? data : data.toString('utf8');
        const msg = JSON.parse(text) as { t: string };
        if (msg.t === 'snapshot') {
          clearTimeout(timer);
          ws.close();
          resolve();
        }
      });
      ws.on('error', (err: Error) => {
        clearTimeout(timer);
        reject(err);
      });
    });
  });

  console.log('[smoke] OK');
}

async function check<T>(label: string, fn: () => Promise<T> | T): Promise<T> {
  try {
    const result = await fn();
    console.log(`[smoke] PASS ${label}`);
    return result as T;
  } catch (err) {
    console.error(`[smoke] FAIL ${label}: ${(err as Error).message}`);
    process.exit(1);
  }
}

void main();
