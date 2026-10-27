import { createHash } from "node:crypto";

/** Stable uppercase UUID derived from a name, so re-seeding keeps every id (scenes reference them). */
export function uuid(name) {
  const hash = createHash("sha1").update(`tmax-demo:${name}`).digest("hex");
  const variant = ((parseInt(hash[16], 16) & 0x3) | 0x8).toString(16);
  return `${hash.slice(0, 8)}-${hash.slice(8, 12)}-5${hash.slice(13, 16)}-${variant}${hash.slice(17, 20)}-${hash.slice(20, 32)}`.toUpperCase();
}

/** Deterministic PRNG (mulberry32) so the generated history looks random but never changes. */
export function random(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

const pad = (value) => String(value).padStart(2, "0");

/** ISO 8601 without fractional seconds: Foundation's `.iso8601` strategy rejects milliseconds. */
export const iso = (date) => date.toISOString().replace(/\.\d{3}Z$/, "Z");
export const isoMilliseconds = (date) => date.toISOString();
export const dayKey = (date) => `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
export const startOfDay = (date) => new Date(date.getFullYear(), date.getMonth(), date.getDate());
export const addDays = (date, days) => new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
export const atMinute = (day, minute) => new Date(day.getFullYear(), day.getMonth(), day.getDate(), Math.floor(minute / 60), minute % 60);
export const addSeconds = (date, seconds) => new Date(date.getTime() + seconds * 1000);
/** 1 = Monday … 7 = Sunday, matching the app's schedule model. */
export const weekday = (date) => ((date.getDay() + 6) % 7) + 1;
export const mondayOf = (date) => addDays(startOfDay(date), 1 - weekday(date));
/** Seconds since 2001-01-01T00:00:00Z, the default `JSONEncoder` date encoding used for UserDefaults blobs. */
export const referenceSeconds = (date) => date.getTime() / 1000 - 978307200;

export function distanceMeters([lat1, lon1], [lat2, lon2]) {
  const radians = Math.PI / 180;
  const dLat = (lat2 - lat1) * radians;
  const dLon = (lon2 - lon1) * radians;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * radians) * Math.cos(lat2 * radians) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

/** Resamples a polyline to points roughly `spacing` meters apart. */
export function resample(coordinates, spacing) {
  const result = [coordinates[0]];
  let carried = 0;
  for (let index = 1; index < coordinates.length; index += 1) {
    const from = coordinates[index - 1];
    const to = coordinates[index];
    const length = distanceMeters(from, to);
    let position = spacing - carried;
    while (position <= length) {
      const t = position / length;
      result.push([from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t]);
      position += spacing;
    }
    carried = length - (position - spacing);
  }
  const last = coordinates[coordinates.length - 1];
  if (distanceMeters(result[result.length - 1], last) > 1) result.push(last);
  return result;
}
