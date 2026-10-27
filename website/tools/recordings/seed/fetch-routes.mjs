#!/usr/bin/env node
// Regenerates seed/routes.json: real path geometry for the demo routes from the public OSM routers
// (routing.openstreetmap.de, ODbL data). Every route stays inside the app's bundled "Vancouver Core" region.
import { writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROUTES = {
  stanleyPark: {
    profile: "foot",
    waypoints: [
      [49.2953, -123.1335], [49.2962, -123.1238], [49.3008, -123.1162], [49.3046, -123.1352],
      [49.3133, -123.1405], [49.3053, -123.1556], [49.3012, -123.1584], [49.2926, -123.1530],
      [49.2938, -123.1398], [49.2953, -123.1335],
    ],
  },
  falseCreek: {
    profile: "foot",
    waypoints: [
      [49.2733, -123.1037], [49.2697, -123.1100], [49.2690, -123.1160], [49.2712, -123.1350],
      [49.2765, -123.1440], [49.2800, -123.1390], [49.2725, -123.1240], [49.2733, -123.1037],
    ],
  },
  kitsJericho: {
    profile: "foot",
    waypoints: [[49.2745, -123.1545], [49.2718, -123.1760], [49.2726, -123.1975], [49.2718, -123.1760], [49.2745, -123.1545]],
  },
  coalHarbour: {
    profile: "foot",
    waypoints: [[49.2888, -123.1111], [49.2905, -123.1240], [49.2930, -123.1310], [49.2905, -123.1240], [49.2888, -123.1111]],
  },
  seawallRide: {
    profile: "bike",
    waypoints: [
      [49.2905, -123.1240], [49.3008, -123.1162], [49.3133, -123.1405], [49.3012, -123.1584],
      [49.2870, -123.1430], [49.2800, -123.1390], [49.2725, -123.1240], [49.2733, -123.1037],
    ],
  },
  liveRun: {
    profile: "foot",
    waypoints: [[49.2888, -123.1111], [49.2905, -123.1240], [49.2962, -123.1238], [49.3008, -123.1162]],
  },
};

async function fetchRoute({ profile, waypoints }) {
  const points = waypoints.map(([lat, lon]) => `${lon},${lat}`).join(";");
  const url = `https://routing.openstreetmap.de/routed-${profile}/route/v1/driving/${points}?overview=full&geometries=geojson`;
  const response = await fetch(url, { headers: { "User-Agent": "tmax-website-recordings/1.0" } });
  const body = await response.json();
  if (body.code !== "Ok") throw new Error(`${profile} route failed: ${body.code} ${body.message ?? ""}`);
  return body.routes[0].geometry.coordinates.map(([lon, lat]) => [Number(lat.toFixed(6)), Number(lon.toFixed(6))]);
}

const result = {};
for (const [key, route] of Object.entries(ROUTES)) {
  result[key] = { profile: route.profile, coordinates: await fetchRoute(route) };
  await new Promise((resolve) => setTimeout(resolve, 1200));
}
const target = path.join(path.dirname(fileURLToPath(import.meta.url)), "routes.json");
await writeFile(target, `${JSON.stringify(result)}\n`);
