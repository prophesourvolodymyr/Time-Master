export type Point = readonly [number, number];

export type Shard = {
  polygon: string;
  box: { x: number; y: number; width: number; height: number };
  origin: string;
  direction: Point;
  distance: number;
  fall: number;
  spin: readonly [number, number, number];
};

export type Fracture = {
  shards: readonly Shard[];
  cracks: readonly string[];
};

function seeded(seed: number) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let value = Math.imul(state ^ (state >>> 15), 1 | state);
    value = (value + Math.imul(value ^ (value >>> 7), 61 | value)) ^ value;
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

const percent = (value: number) => `${(value * 100).toFixed(2)}%`;

export function fracture(impact: Point, rays: number, rings: readonly number[], seed: number): Fracture {
  const random = seeded(seed);
  const angles = Array.from({ length: rays }, (_, index) => ((index + (random() - 0.5) * 0.7) / rays) * Math.PI * 2);
  const grid = rings.map((radius) =>
    angles.map((angle): Point => {
      const reach = radius * (1 + (random() - 0.5) * 0.34);
      return [impact[0] + Math.cos(angle) * reach, impact[1] + Math.sin(angle) * reach];
    }),
  );

  const shards: Shard[] = [];
  for (let ring = 0; ring < rings.length - 1; ring += 1) {
    for (let ray = 0; ray < rays; ray += 1) {
      const next = (ray + 1) % rays;
      const corners = [grid[ring][ray], grid[ring][next], grid[ring + 1][next], grid[ring + 1][ray]];
      const xs = corners.map(([x]) => Math.min(1, Math.max(0, x)));
      const ys = corners.map(([, y]) => Math.min(1, Math.max(0, y)));
      const box = { x: Math.min(...xs), y: Math.min(...ys), width: Math.max(...xs) - Math.min(...xs), height: Math.max(...ys) - Math.min(...ys) };
      if (box.width < 0.004 || box.height < 0.004) continue;
      const center: Point = [xs.reduce((sum, x) => sum + x, 0) / 4, ys.reduce((sum, y) => sum + y, 0) / 4];
      const offset: Point = [center[0] - impact[0], center[1] - impact[1]];
      const length = Math.hypot(offset[0], offset[1]) || 1;
      shards.push({
        polygon: `polygon(${corners.map(([x, y]) => `${percent((x - box.x) / box.width)} ${percent((y - box.y) / box.height)}`).join(", ")})`,
        box,
        origin: `${percent((center[0] - box.x) / box.width)} ${percent((center[1] - box.y) / box.height)}`,
        direction: [offset[0] / length, offset[1] / length],
        distance: 0.35 + random() * 0.55 + ring * 0.12,
        fall: 0.2 + random() * 0.45,
        spin: [(random() - 0.5) * 220, (random() - 0.5) * 220, (random() - 0.5) * 260],
      });
    }
  }

  const labels = grid.map((ring) => ring.map(([x, y]) => `${(x * 100).toFixed(2)} ${(y * 100).toFixed(2)}`));
  const cracks = [
    ...angles.map((_, ray) => `M ${labels.map((ring) => ring[ray]).join(" L ")}`),
    ...labels.slice(1, -1).flatMap((ring) => ring.map((label, ray) => `M ${label} L ${ring[(ray + 1) % rays]}`).filter(() => random() < 0.55)),
  ];

  return { shards, cracks };
}
