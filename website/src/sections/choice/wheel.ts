export type WheelState = {
  target: number;
  current: number;
};

const detentSharpness = 2.4;

export function detent(position: number) {
  const base = Math.floor(position);
  const fraction = position - base;
  const eased = fraction < 0.5 ? 0.5 * Math.pow(2 * fraction, detentSharpness) : 1 - 0.5 * Math.pow(2 * (1 - fraction), detentSharpness);
  return base + eased;
}

export function focusWeight(offset: number) {
  return Math.exp(-offset * offset * 1.4);
}
