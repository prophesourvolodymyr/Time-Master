import { stat } from "node:fs/promises";
import { run } from "./process.mjs";

export const CLIP_WIDTH = 720;
export const CLIP_HEIGHT = 1566;
const MAX_BITRATE = "1150k";

export async function probeDuration(file) {
  const { stdout } = await run("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", file]);
  return Number(stdout.trim());
}

/** Spans where the picture actually changes, from ffmpeg's freezedetect (frozen = no visible motion). */
export async function motionBounds(file) {
  const total = await probeDuration(file);
  const { stderr } = await run("ffmpeg", ["-hide_banner", "-i", file, "-vf", "freezedetect=n=0.0015:d=0.25", "-map", "0:v:0", "-f", "null", "-"]);
  const starts = [...stderr.matchAll(/freeze_start: ([\d.]+)/g)].map((match) => Number(match[1]));
  const ends = [...stderr.matchAll(/freeze_end: ([\d.]+)/g)].map((match) => Number(match[1]));
  const firstMotion = starts.length && starts[0] < 0.05 ? (ends[0] ?? total) : 0;
  const lastMotion = starts.length > ends.length ? starts[starts.length - 1] : total;
  return { total, firstMotion, lastMotion };
}

/**
 * H.264 High, yuv420p, 30 fps CFR, 720 px wide, faststart, silent; poster = first encoded frame.
 * The simulator records Display P3 primaries with the sRGB curve; the clip is converted to BT.709
 * primaries (sRGB curve kept) so the app's orange matches the page's sRGB orange in every browser.
 * simctl writes frames only when the screen changes, so the trim runs after the CFR conversion:
 * seeking the input instead would drop a still frame that is held across the start point.
 */
export async function encodeClip({ raw, output, poster, start, duration }) {
  await run("ffmpeg", [
    "-hide_banner", "-loglevel", "error", "-y",
    "-i", raw, "-t", duration.toFixed(3),
    "-vf", [
      "tpad=stop_mode=clone:stop_duration=5",
      "fps=30",
      `trim=start=${start.toFixed(3)}`,
      "setpts=PTS-STARTPTS",
      `scale=${CLIP_WIDTH}:${CLIP_HEIGHT}:flags=lanczos`,
      "colorspace=all=bt709:trc=srgb:iall=bt709:iprimaries=smpte432:itrc=srgb:format=yuv420p",
    ].join(","),
    "-c:v", "libx264", "-profile:v", "high", "-preset", "slower", "-crf", "24",
    "-maxrate", MAX_BITRATE, "-bufsize", "2300k", "-g", "60", "-keyint_min", "30",
    "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "iec61966-2-1",
    "-movflags", "+faststart", "-an", output,
  ]);
  await run("ffmpeg", [
    "-hide_banner", "-loglevel", "error", "-y", "-i", output, "-frames:v", "1",
    "-vf", "scale=in_color_matrix=bt709:in_range=tv:out_color_matrix=bt601:out_range=pc,format=yuvj420p",
    "-q:v", "3", poster,
  ]);
  const [{ size }, actual] = await Promise.all([stat(output), probeDuration(output)]);
  return { bytes: size, duration: Number(actual.toFixed(2)) };
}
