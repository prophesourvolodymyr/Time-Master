"use client";

import { ChapterShell } from "../shared/chapter-shell";
import { FeatureBeat } from "../shared/feature-beat";
import { BuildStack } from "./build-stack";

export function BuilderChapter() {
  return (
    <ChapterShell id="builder">
      <BuildStack />
      <FeatureBeat
        clip="builder"
        title="Drag. Drop. Done."
        lines={["Drag exercises from your library straight into a workout.", "Sets, reps, rest and timing live right on the card."]}
      />
      <FeatureBeat
        clip="builder-long"
        side="right"
        title="Bundles that shuffle."
        lines={["Group moves into one timed bundle.", "Run them in order, or shuffle them every set so your body never gets comfortable."]}
      />
      <FeatureBeat
        clip="music"
        title="A soundtrack with a timeline."
        lines={["Place songs and playlists on the workout's own music timeline.", "Your main track takes over, then the background picks up where it left off."]}
      />
      <FeatureBeat
        clip="workout-player"
        side="right"
        title="Edit while you sweat."
        lines={["Change sets mid-workout without stopping the clock.", "The timer follows you to the Lock Screen and the Dynamic Island."]}
      />
      <FeatureBeat
        clip="schedule"
        title="On schedule. On you."
        lines={["Plan the week by day and time.", "Miss one and Tmax nudges you an hour after your reminder."]}
      />
    </ChapterShell>
  );
}
