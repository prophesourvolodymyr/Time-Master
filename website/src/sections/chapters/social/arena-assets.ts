export type ArenaAssetId =
  | "arena"
  | "monument"
  | "spectator-instagram"
  | "spectator-tiktok"
  | "spectator-youtube"
  | "spectator-x"
  | "spectator-facebook"
  | "tablet-tiktok"
  | "dust";

export type MarkBox = { x: number; y: number; width: number; height: number };

export type ArenaAsset = { width: number; height: number; widths: readonly number[]; mark?: MarkBox };

export const arenaAssets: Record<ArenaAssetId, ArenaAsset> = {
  "arena": { width: 1672, height: 941, widths: [1672, 960] },
  "monument": { width: 1024, height: 1072, widths: [1024, 560], mark: { x: 0.2734, y: 0.2052, width: 0.4482, height: 0.2761 } },
  "spectator-instagram": { width: 1010, height: 1199, widths: [1010, 560], mark: { x: 0.4337, y: 0.241, width: 0.3287, height: 0.4178 } },
  "spectator-tiktok": { width: 869, height: 1346, widths: [869, 560], mark: { x: 0.4062, y: 0.1805, width: 0.3326, height: 0.2964 } },
  "spectator-youtube": { width: 999, height: 1164, widths: [999, 560], mark: { x: 0.2613, y: 0.25, width: 0.3664, height: 0.3402 } },
  "spectator-x": { width: 858, height: 1349, widths: [858, 560], mark: { x: 0.2331, y: 0.1698, width: 0.4114, height: 0.3032 } },
  "spectator-facebook": { width: 760, height: 1421, widths: [760, 480], mark: { x: 0.3908, y: 0.1597, width: 0.4079, height: 0.2906 } },
  "tablet-tiktok": { width: 1001, height: 1010, widths: [1001, 640], mark: { x: 0.2677, y: 0.2327, width: 0.4645, height: 0.5436 } },
  "dust": { width: 1672, height: 941, widths: [1280, 720] },
};
