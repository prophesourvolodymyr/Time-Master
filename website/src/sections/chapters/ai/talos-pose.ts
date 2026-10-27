export type TalosPose = {
  turn: number;
  spin: number;
  light: number;
  flash: number;
  float: number;
  accentR: number;
  accentG: number;
  accentB: number;
};

export type AccentChannels = Pick<TalosPose, "accentR" | "accentG" | "accentB">;

export const talosOrange = "#FF6A00";

export function accentChannels(hex: string): AccentChannels {
  const value = Number.parseInt(hex.replace("#", ""), 16);
  return {
    accentR: ((value >> 16) & 255) / 255,
    accentG: ((value >> 8) & 255) / 255,
    accentB: (value & 255) / 255,
  };
}

export function createTalosPose(): TalosPose {
  return { turn: 0.32, spin: 0, light: 1, flash: 0, float: 1, ...accentChannels(talosOrange) };
}
