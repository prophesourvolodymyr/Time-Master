import { ChapterSlot } from "./chapter-slot";
import { DownloadBand } from "./download-band";
import { ObsessionWheel } from "./obsession-wheel";
import styles from "./choice.module.css";

export function ChoiceSection() {
  return (
    <section id="choose" aria-labelledby="choose-title">
      <ObsessionWheel />
      <div className={styles.bandWrap}>
        <DownloadBand />
      </div>
      <ChapterSlot />
    </section>
  );
}
