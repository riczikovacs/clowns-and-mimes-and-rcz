import type { Topology, Vec2 } from './protocol.ts';

/**
 * Wrap a position into the canonical domain for the topology.
 * The domain is the centered square [-w/2, w/2] x [-w/2, w/2].
 * Server and client must agree on this so that rendering, physics, and
 * pathfinding all see the same coordinate space.
 */
export function wrapPosition(p: Vec2, topology: Topology, width: number): Vec2 {
  const half = width / 2;
  switch (topology) {
    case 'plane': {
      return {
        x: clamp(p.x, -half, half),
        z: clamp(p.z, -half, half),
      };
    }
    case 'torus': {
      return {
        x: wrap(p.x, width),
        z: wrap(p.z, width),
      };
    }
    case 'klein': {
      const wrappedX = wrap(p.x, width);
      const xCrossings = Math.floor((p.x + half) / width);
      const flipZ = xCrossings % 2 !== 0;
      const z0 = flipZ ? -p.z : p.z;
      return {
        x: wrappedX,
        z: wrap(z0, width),
      };
    }
    case 'sphere': {
      // Stereographic-style wrap. Outside the disk we wrap to the antipode.
      const r = Math.sqrt(p.x * p.x + p.z * p.z);
      if (r <= half) return { x: p.x, z: p.z };
      const k = (width - r) / r;
      return { x: p.x * k, z: p.z * k };
    }
  }
}

export function topologyDistance(a: Vec2, b: Vec2, topology: Topology, width: number): number {
  switch (topology) {
    case 'plane':
      return Math.hypot(a.x - b.x, a.z - b.z);
    case 'torus': {
      const dx = wrappedDelta(a.x, b.x, width);
      const dz = wrappedDelta(a.z, b.z, width);
      return Math.hypot(dx, dz);
    }
    case 'klein': {
      const dxA = wrappedDelta(a.x, b.x, width);
      const flipped = Math.abs(a.x - b.x) > width / 2;
      const bz = flipped ? -b.z : b.z;
      const dzA = wrappedDelta(a.z, bz, width);
      return Math.hypot(dxA, dzA);
    }
    case 'sphere': {
      const half = width / 2;
      const ax = (a.x / half) * Math.PI;
      const az = (a.z / half) * Math.PI;
      const bx = (b.x / half) * Math.PI;
      const bz = (b.z / half) * Math.PI;
      const dx = Math.cos(ax) * Math.cos(az) - Math.cos(bx) * Math.cos(bz);
      const dy = Math.sin(ax) * Math.cos(az) - Math.sin(bx) * Math.cos(bz);
      const dz = Math.sin(az) - Math.sin(bz);
      return half * Math.acos(1 - (dx * dx + dy * dy + dz * dz) / 2);
    }
  }
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, v));
}

function wrap(v: number, width: number): number {
  const half = width / 2;
  const w = (((v + half) % width) + width) % width;
  return w - half;
}

function wrappedDelta(a: number, b: number, width: number): number {
  const d = (((b - a) % width) + width) % width;
  return d > width / 2 ? d - width : d;
}
