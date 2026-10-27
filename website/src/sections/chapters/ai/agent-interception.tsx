import type { Ref } from "react";
import { DownloadButtons } from "@/components/downloads/download-buttons";
import { CardSurface } from "@/components/ui";
import { agentDemo } from "./content";
import styles from "./ai-chapter.module.css";

export type AgentInterceptionProps = {
  countdown: number | null;
  panelRef?: Ref<HTMLDivElement>;
  onHoldChange?: (held: boolean) => void;
};

export function AgentInterception({ countdown, panelRef, onHoldChange }: AgentInterceptionProps) {
  return (
    <div ref={panelRef} className={styles.interceptionFrame}>
      <CardSurface
        emphasized
        className={styles.interception}
        onPointerEnter={() => onHoldChange?.(true)}
        onPointerLeave={() => onHoldChange?.(false)}
        onFocus={() => onHoldChange?.(true)}
        onBlur={(event) => {
          if (!event.currentTarget.contains(event.relatedTarget)) onHoldChange?.(false);
        }}
      >
        <p className={styles.interceptionKicker}>Wait.</p>
        <p className={styles.interceptionTitle}>
          <span className={styles.handle}>@{agentDemo.username}</span> is free. For now.
        </p>
        <p className={styles.interceptionLine}>Only the app can claim it, and usernames are first come, first served.</p>
        <DownloadButtons stacked className={styles.interceptionButtons} />
        {countdown === null ? null : (
          <p className={styles.countdown} aria-hidden="true">
            This demo self-destructs in <span className={styles.countdownValue}>{countdown}</span>
          </p>
        )}
      </CardSurface>
    </div>
  );
}
