import { ChapterSlot } from "./chapter-slot";
import { ObsessionWheel } from "./obsession-wheel";

export function ChoiceSection() {
  return (
    <section id="choose" aria-labelledby="choose-title">
      <ObsessionWheel />
      <ChapterSlot />
    </section>
  );
}
