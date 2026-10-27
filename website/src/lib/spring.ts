export type SpringEasing = {
  easing: string;
  duration: number;
};

const settleThreshold = 0.001;

function displacement(t: number, omega: number, zeta: number) {
  if (zeta < 1) {
    const damped = omega * Math.sqrt(1 - zeta * zeta);
    return Math.exp(-zeta * omega * t) * (Math.cos(damped * t) + ((zeta * omega) / damped) * Math.sin(damped * t));
  }
  return Math.exp(-omega * t) * (1 + omega * t);
}

export function springEasing(response: number, dampingFraction: number, samples = 40): SpringEasing {
  const omega = (2 * Math.PI) / response;
  const zeta = Math.min(dampingFraction, 1);
  const duration = Math.log(1 / settleThreshold) / (zeta * omega);
  const points: string[] = [];
  for (let index = 0; index <= samples; index += 1) {
    const progress = index / samples;
    const value = 1 - displacement(progress * duration, omega, zeta);
    points.push(index === 0 ? "0" : index === samples ? "1" : `${value.toFixed(4)} ${(progress * 100).toFixed(1)}%`);
  }
  return { easing: `linear(${points.join(", ")})`, duration: Number(duration.toFixed(3)) };
}

export const pressSpring = springEasing(0.24, 0.88);
