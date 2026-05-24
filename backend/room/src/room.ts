import type {
  ClientToServer,
  PlayerInput,
  PlayerState,
  RoomPhase,
  RoomSnapshot,
  ServerToClient,
  Team,
  Topology,
} from '@cm/shared';
import { PROTOCOL_VERSION } from '@cm/shared';
import { topologyDistance, wrapPosition } from '@cm/shared/topology';

const TICK_HZ = 20;
const TICK_MS = 1000 / TICK_HZ;
const FREE_ROAM_MS = 60_000;
const COUNTDOWN_MS = 10_000;
const TAG_RADIUS = 1.4;
const UNFREEZE_RADIUS = 1.4;
const WORLD_WIDTH = 80;
const MAX_PLAYERS = 16;
const TEAM_TARGET = 4;
const MAX_SPRINT = 100;
const SPRINT_DRAIN_PER_S = 25;
const SPRINT_REGEN_PER_S = 15;
const WALK_SPEED = 3.2;
const SPRINT_SPEED = 5.6;
const MAX_TICK_TRAVEL = SPRINT_SPEED * 1.5; // anti-cheat: clamp per-tick displacement
const TURN_FIRST_MS = 30_000;
const TURN_STEP_MS = 30_000;
const TURN_CAP_MS = 5 * 60_000;

interface Connection {
  ws: WebSocket;
  playerId: string;
}

export class Room implements DurableObject {
  private readonly connections = new Map<WebSocket, Connection>();
  private readonly players = new Map<string, PlayerState>();
  private readonly lastInputs = new Map<string, PlayerInput>();
  private phase: RoomPhase = 'filling';
  private turnEndsAt = 0;
  private topology: Topology = 'plane';
  private seed = Math.floor(Math.random() * 2 ** 31);
  private roundNumber = 0;
  private firstTeam: Team = 'mime';
  private tickHandle: ReturnType<typeof setInterval> | null = null;

  constructor(private readonly state: DurableObjectState) {}

  async fetch(req: Request): Promise<Response> {
    if (req.headers.get('upgrade') !== 'websocket') {
      return new Response('expected websocket', { status: 426 });
    }
    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    this.state.acceptWebSocket(server);
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): void {
    let msg: ClientToServer;
    try {
      msg = JSON.parse(
        typeof raw === 'string' ? raw : new TextDecoder().decode(raw),
      ) as ClientToServer;
    } catch {
      this.send(ws, { t: 'error', code: 'invalid_message', message: 'bad json' });
      return;
    }
    this.handleMessage(ws, msg);
  }

  webSocketClose(ws: WebSocket): void {
    this.detach(ws);
  }

  webSocketError(ws: WebSocket): void {
    this.detach(ws);
  }

  private handleMessage(ws: WebSocket, msg: ClientToServer): void {
    switch (msg.t) {
      case 'join':
        this.onJoin(ws, msg.name, msg.v, msg.preferTeam);
        return;
      case 'leave':
        this.detach(ws);
        return;
      case 'input':
        this.onInput(ws, msg.input);
        return;
      case 'tag_attempt':
        this.onTag(ws, msg.targetId);
        return;
      case 'unfreeze_attempt':
        this.onUnfreeze(ws, msg.targetId);
        return;
      case 'ping':
        this.send(ws, { t: 'pong', clientTime: msg.clientTime, serverTime: Date.now() });
        return;
    }
  }

  private onJoin(ws: WebSocket, name: string, version: number, prefer?: Team): void {
    if (version !== PROTOCOL_VERSION) {
      this.send(ws, { t: 'error', code: 'version_mismatch', message: 'update your client' });
      ws.close(4001, 'version');
      return;
    }
    if (this.humanPlayers().length >= MAX_PLAYERS - this.botPlayers().length) {
      this.send(ws, { t: 'error', code: 'room_full', message: 'room full' });
      ws.close(4002, 'full');
      return;
    }
    const id = crypto.randomUUID();
    const team = prefer ?? this.pickTeam();
    const player: PlayerState = {
      id,
      name: this.sanitizeName(name),
      team,
      bot: false,
      position: { x: 0, z: 0 },
      yaw: 0,
      frozen: false,
      sprintEnergy: MAX_SPRINT,
    };
    this.players.set(id, player);
    this.connections.set(ws, { ws, playerId: id });
    this.send(ws, { t: 'snapshot', snapshot: this.snapshot(), youAre: id });
    this.broadcast({ t: 'event', kind: { kind: 'phase', phase: this.phase } });
    if (this.phase === 'filling' && this.humanPlayers().length >= 2 && !this.tickHandle) {
      this.startCountdown();
    }
  }

  /** Fill empty slots with bots up to TEAM_TARGET per team. Idempotent. */
  fillBots(): void {
    for (const team of ['mime', 'clown'] as const) {
      while (this.tally(team) < TEAM_TARGET) {
        const id = crypto.randomUUID();
        this.players.set(id, {
          id,
          name: `Bot-${id.slice(0, 4)}`,
          team,
          bot: true,
          position: { x: (Math.random() - 0.5) * 4, z: (Math.random() - 0.5) * 4 },
          yaw: 0,
          frozen: false,
          sprintEnergy: MAX_SPRINT,
        });
      }
    }
  }

  setTopology(t: Topology): void {
    this.topology = t;
  }

  private detach(ws: WebSocket): void {
    const conn = this.connections.get(ws);
    if (!conn) return;
    this.connections.delete(ws);
    this.players.delete(conn.playerId);
    this.lastInputs.delete(conn.playerId);
    if (this.humanPlayers().length === 0) {
      this.stopTick();
      this.phase = 'filling';
    }
  }

  private onInput(ws: WebSocket, input: PlayerInput): void {
    const conn = this.connections.get(ws);
    if (!conn) return;
    this.lastInputs.set(conn.playerId, input);
  }

  private onTag(ws: WebSocket, targetId: string): void {
    const conn = this.connections.get(ws);
    if (!conn) return;
    const attacker = this.players.get(conn.playerId);
    const victim = this.players.get(targetId);
    if (!attacker || !victim) {
      this.send(ws, { t: 'tag_result', ok: false, reason: 'missing' });
      return;
    }
    if (!this.canTag(attacker, victim)) {
      this.send(ws, { t: 'tag_result', ok: false, reason: 'invalid' });
      return;
    }
    victim.frozen = true;
    this.send(ws, { t: 'tag_result', ok: true, targetId });
    this.broadcast({
      t: 'event',
      kind: { kind: 'tagged', attackerId: attacker.id, victimId: victim.id, team: attacker.team },
    });
    this.checkWin();
  }

  private onUnfreeze(ws: WebSocket, targetId: string): void {
    const conn = this.connections.get(ws);
    if (!conn) return;
    const savior = this.players.get(conn.playerId);
    const victim = this.players.get(targetId);
    if (!savior || !victim || !victim.frozen || savior.team !== victim.team) {
      this.send(ws, { t: 'unfreeze_result', ok: false, reason: 'invalid' });
      return;
    }
    if (
      topologyDistance(savior.position, victim.position, this.topology, WORLD_WIDTH) >
      UNFREEZE_RADIUS
    ) {
      this.send(ws, { t: 'unfreeze_result', ok: false, reason: 'out_of_range' });
      return;
    }
    victim.frozen = false;
    this.send(ws, { t: 'unfreeze_result', ok: true, targetId });
    this.broadcast({
      t: 'event',
      kind: { kind: 'saved', saviorId: savior.id, victimId: victim.id },
    });
  }

  private canTag(attacker: PlayerState, victim: PlayerState): boolean {
    if (attacker.team === victim.team) return false;
    if (attacker.frozen) return false;
    if (victim.frozen) return false;
    if (this.phase !== `turn_${attacker.team}`) return false;
    const d = topologyDistance(attacker.position, victim.position, this.topology, WORLD_WIDTH);
    return d <= TAG_RADIUS;
  }

  private tally(team: Team): number {
    let n = 0;
    for (const p of this.players.values()) if (p.team === team) n += 1;
    return n;
  }

  private humanPlayers(): PlayerState[] {
    return [...this.players.values()].filter((p) => !p.bot);
  }

  private botPlayers(): PlayerState[] {
    return [...this.players.values()].filter((p) => p.bot);
  }

  private pickTeam(): Team {
    return this.tally('mime') <= this.tally('clown') ? 'mime' : 'clown';
  }

  private sanitizeName(name: string): string {
    return name.replace(/[^\w \-.]/g, '').slice(0, 24) || 'Player';
  }

  private checkWin(): void {
    const mimesActive = [...this.players.values()].filter((p) => p.team === 'mime' && !p.frozen);
    const clownsActive = [...this.players.values()].filter((p) => p.team === 'clown' && !p.frozen);
    if (mimesActive.length === 0) {
      this.phase = 'ended';
      this.broadcast({ t: 'event', kind: { kind: 'win', team: 'clown' } });
      this.stopTick();
    } else if (clownsActive.length === 0) {
      this.phase = 'ended';
      this.broadcast({ t: 'event', kind: { kind: 'win', team: 'mime' } });
      this.stopTick();
    }
  }

  private startCountdown(): void {
    this.firstTeam = Math.random() < 0.5 ? 'mime' : 'clown';
    this.phase = 'countdown';
    this.turnEndsAt = Date.now() + COUNTDOWN_MS;
    this.broadcast({ t: 'event', kind: { kind: 'phase', phase: this.phase } });
    this.tickHandle = setInterval(() => this.tick(), TICK_MS);
  }

  private tick(): void {
    const now = Date.now();
    if (this.phase === 'countdown' && now >= this.turnEndsAt) {
      this.phase = 'free_roam';
      this.turnEndsAt = now + FREE_ROAM_MS;
      this.broadcast({ t: 'event', kind: { kind: 'phase', phase: this.phase } });
    } else if (this.phase === 'free_roam' && now >= this.turnEndsAt) {
      this.beginNextTurn();
    } else if (
      (this.phase === 'turn_mime' || this.phase === 'turn_clown') &&
      now >= this.turnEndsAt
    ) {
      this.beginNextTurn();
    }
    this.simulate();
    this.broadcastDelta();
  }

  private beginNextTurn(): void {
    this.roundNumber += 1;
    const next: Team =
      this.phase === 'turn_mime' ? 'clown' : this.phase === 'turn_clown' ? 'mime' : this.firstTeam;
    this.phase = `turn_${next}` as RoomPhase;
    const ms = Math.min(TURN_CAP_MS, TURN_FIRST_MS + (this.roundNumber - 1) * TURN_STEP_MS);
    this.turnEndsAt = Date.now() + ms;
    this.broadcast({ t: 'event', kind: { kind: 'phase', phase: this.phase } });
  }

  /** Applies player inputs with anti-cheat distance clamping. */
  private simulate(): void {
    const dt = TICK_MS / 1000;
    for (const [id, input] of this.lastInputs) {
      const p = this.players.get(id);
      if (!p || p.bot || p.frozen) continue;
      const wantSprint = input.sprint && p.sprintEnergy > 0;
      const speed = wantSprint ? SPRINT_SPEED : WALK_SPEED;
      const moveLen = Math.hypot(input.move.x, input.move.z);
      const nx = moveLen > 0 ? input.move.x / moveLen : 0;
      const nz = moveLen > 0 ? input.move.z / moveLen : 0;
      const dx = nx * speed * dt;
      const dz = nz * speed * dt;
      const travel = Math.hypot(dx, dz);
      const scale = travel > MAX_TICK_TRAVEL * dt ? (MAX_TICK_TRAVEL * dt) / travel : 1;
      const next = { x: p.position.x + dx * scale, z: p.position.z + dz * scale };
      p.position = wrapPosition(next, this.topology, WORLD_WIDTH);
      p.yaw = input.lookYaw;
      const drained = wantSprint && moveLen > 0;
      p.sprintEnergy = clamp(
        p.sprintEnergy + (drained ? -SPRINT_DRAIN_PER_S : SPRINT_REGEN_PER_S) * dt,
        0,
        MAX_SPRINT,
      );
    }
  }

  private broadcastDelta(): void {
    const players = [...this.players.values()];
    for (const conn of this.connections.values()) {
      const last = this.lastInputs.get(conn.playerId);
      this.send(conn.ws, {
        t: 'delta',
        players,
        phase: this.phase,
        turnEndsAt: this.turnEndsAt,
        ackSeq: last?.seq ?? 0,
      });
    }
  }

  private snapshot(): RoomSnapshot {
    return {
      v: PROTOCOL_VERSION,
      roomId: this.state.id.toString(),
      seed: this.seed,
      topology: this.topology,
      phase: this.phase,
      turnEndsAt: this.turnEndsAt,
      players: [...this.players.values()],
    };
  }

  private broadcast(msg: ServerToClient): void {
    for (const conn of this.connections.values()) {
      this.send(conn.ws, msg);
    }
  }

  private send(ws: WebSocket, msg: ServerToClient): void {
    try {
      ws.send(JSON.stringify(msg));
    } catch {
      // socket likely closed; cleanup happens on close event
    }
  }

  private stopTick(): void {
    if (this.tickHandle !== null) {
      clearInterval(this.tickHandle);
      this.tickHandle = null;
    }
  }
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, v));
}
