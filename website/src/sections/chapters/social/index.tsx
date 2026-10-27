"use client";

import { ChapterShell } from "../shared/chapter-shell";
import { FeatureBeat } from "../shared/feature-beat";
import { ArenaOpening } from "./arena-opening";
import { PoseChips, TierLadder } from "./beat-asides";
import { Companion } from "./companion";
import { LootMoment } from "./loot-moment";

export function SocialChapter() {
  return (
    <ChapterShell id="social">
      <div className="relative">
        <Companion cue="[data-social-beats]" />
        <ArenaOpening />
        <div data-social-beats>
          <FeatureBeat
            clip="social-long"
            title="Social, with sweat."
            lines={["Profiles, posts, Ranked battles, Physique Duels and collectibles. One app.", "Other feeds watch you scroll. This one watches you squat."]}
          />
          <FeatureBeat
            clip="profile"
            side="right"
            title="A profile that lifts."
            lines={[
              "Avatar, banner, bio, links and your recent workouts on one page.",
              "Post your day with a photo, then react, reply and edit.",
              "Add Markdown comments to your exercise media, with a live preview.",
            ]}
          />
          <FeatureBeat
            clip="ranked"
            title="Reps decide the rank."
            lines={[
              "Camera-tracked 1v1 battles in push-ups, squats and planks.",
              "Half reps don't count. The camera noticed.",
              "Climb from Iron to Champion with an Elo for every exact movement.",
            ]}
            aside={<TierLadder from="right" />}
          />
          <FeatureBeat
            clip="duels"
            side="right"
            title="Flex. Get judged."
            lines={[
              "Physique Duels: three poses, one AI judge, zero mercy.",
              "Scored on muscularity, definition, symmetry and presentation.",
              "Five placement matches, then your Physique Elo is on the line.",
            ]}
            aside={<PoseChips from="left" />}
          />
          <LootMoment />
          <FeatureBeat
            clip="collectibles"
            title="Dress like a champion."
            lines={[
              "Icon rings, name styles, badge skins and profile styles. Season one is called First light.",
              "Try any look on your real profile. Your saved style stays put.",
            ]}
          />
        </div>
      </div>
    </ChapterShell>
  );
}
