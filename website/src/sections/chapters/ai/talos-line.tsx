import clsx from "clsx";
import { BorderSlide } from "@/components/motion/border-slide";
import type { TalosBeat } from "./content";
import { TalosPoster } from "./talos-stage";
import styles from "./ai-chapter.module.css";

export function TalosLine({ beat, still }: { beat: TalosBeat; still: boolean }) {
  const textFrom = beat.side === "left" ? "right" : "left";
  return (
    <section className={clsx(styles.line, beat.side === "left" ? styles.lineEnd : styles.lineStart)}>
      {still ? <TalosPoster className={styles.linePoster} /> : null}
      <div className={styles.lineText}>
        <BorderSlide from={textFrom} duration={0.9}>
          <h3 className={styles.lineTitle}>{beat.title}</h3>
        </BorderSlide>
        <BorderSlide from={textFrom} delay={0.08} duration={0.8}>
          <p className={styles.lineCopy}>{beat.line}</p>
        </BorderSlide>
      </div>
    </section>
  );
}
