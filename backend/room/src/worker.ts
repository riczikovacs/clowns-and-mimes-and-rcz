import { Room } from './room.ts';

export { Room };

export interface Env {
  ROOM: DurableObjectNamespace;
  MATCHMAKER_URL?: string;
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === '/healthz') {
      return new Response('ok');
    }
    const m = url.pathname.match(/^\/ws\/([0-9a-f-]+)$/i);
    if (!m) return new Response('not found', { status: 404 });
    const id = env.ROOM.idFromName(m[1]!);
    const stub = env.ROOM.get(id);
    return stub.fetch(req);
  },
};
