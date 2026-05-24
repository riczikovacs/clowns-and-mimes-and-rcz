import type {
  MatchmakeCreateBody,
  MatchmakeCreateResponse,
  MatchmakeJoinResponse,
  Topology,
} from '@cm/shared';

export interface Env {
  LOBBY_CODES: KVNamespace;
  ROOM_WORKER: string;
  ENV: string;
}

const VALID_TOPOLOGIES: readonly Topology[] = ['plane', 'torus', 'klein', 'sphere'];
const CODE_LENGTH = 6;
const CODE_ALPHABET = 'BCDFGHJKLMNPQRSTVWXYZ23456789';

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (req.method === 'GET' && url.pathname === '/healthz') {
      return json({ ok: true, env: env.ENV });
    }
    if (req.method === 'POST' && url.pathname === '/lobby') {
      return createLobby(req, env);
    }
    const joinMatch = url.pathname.match(/^\/lobby\/([A-Z0-9]+)\/join$/);
    if (req.method === 'POST' && joinMatch) {
      return joinByCode(joinMatch[1]!, env);
    }
    if (req.method === 'POST' && url.pathname === '/open/join') {
      return joinOpen(env);
    }
    return notFound();
  },
};

async function createLobby(req: Request, env: Env): Promise<Response> {
  let body: MatchmakeCreateBody;
  try {
    body = (await req.json()) as MatchmakeCreateBody;
  } catch {
    return error(400, 'invalid_json');
  }
  if (!VALID_TOPOLOGIES.includes(body.topology)) {
    return error(400, 'invalid_topology');
  }
  const code = await freshCode(env);
  const roomId = crypto.randomUUID();
  await env.LOBBY_CODES.put(
    code,
    JSON.stringify({ roomId, topology: body.topology, createdAt: Date.now() }),
    { expirationTtl: 60 * 60 * 6 },
  );
  const wsUrl = wsUrlFor(env, roomId);
  const res: MatchmakeCreateResponse = { code, roomId, wsUrl };
  return json(res);
}

async function joinByCode(code: string, env: Env): Promise<Response> {
  const raw = await env.LOBBY_CODES.get(code);
  if (!raw) return error(404, 'room_not_found');
  const parsed = JSON.parse(raw) as { roomId: string; topology: Topology };
  const res: MatchmakeJoinResponse = {
    roomId: parsed.roomId,
    wsUrl: wsUrlFor(env, parsed.roomId),
  };
  return json(res);
}

async function joinOpen(env: Env): Promise<Response> {
  // First cut: every join opens a fresh room with a random topology.
  // A future revision will coalesce joins into rooms with capacity using a queue Durable Object.
  const topology = VALID_TOPOLOGIES[Math.floor(Math.random() * VALID_TOPOLOGIES.length)]!;
  const roomId = crypto.randomUUID();
  await env.LOBBY_CODES.put(
    `open:${roomId}`,
    JSON.stringify({ roomId, topology, open: true, createdAt: Date.now() }),
    { expirationTtl: 60 * 30 },
  );
  const res: MatchmakeJoinResponse = { roomId, wsUrl: wsUrlFor(env, roomId) };
  return json(res);
}

async function freshCode(env: Env): Promise<string> {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const code = randomCode();
    const existing = await env.LOBBY_CODES.get(code);
    if (!existing) return code;
  }
  throw new Error('failed to allocate code');
}

function randomCode(): string {
  const buf = new Uint8Array(CODE_LENGTH);
  crypto.getRandomValues(buf);
  let out = '';
  for (const byte of buf) {
    out += CODE_ALPHABET[byte % CODE_ALPHABET.length];
  }
  return out;
}

function wsUrlFor(env: Env, roomId: string): string {
  // The room worker accepts WS upgrades on /ws/<roomId>.
  return `wss://${env.ROOM_WORKER}.workers.dev/ws/${roomId}`;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function notFound(): Response {
  return error(404, 'not_found');
}

function error(status: number, code: string): Response {
  return json({ error: code }, status);
}
