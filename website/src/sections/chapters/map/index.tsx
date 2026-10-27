"use client";

import { ChapterShell } from "../shared/chapter-shell";
import { FeatureBeat } from "../shared/feature-beat";
import { RouteScene } from "./route-scene";

export function MapChapter() {
  return (
    <ChapterShell id="map">
      <RouteScene />
      <FeatureBeat
        clip="map-recording"
        title="Hit record. Go."
        lines={["Run, walk or ride with live GPS on the map.", "Pause, lap, keep going. Every second is kept."]}
      />
      <FeatureBeat
        clip="routes"
        side="right"
        title="Every route, yours."
        lines={["Trips live on your phone first, not on someone else's server.", "Export GPX or CSV whenever you want."]}
      />
      <FeatureBeat
        clip="map-long"
        title="The long way home."
        lines={["Plan a route, follow it, then replay how it went.", "Pace, distance and time, right where you ran them."]}
      />
    </ChapterShell>
  );
}
