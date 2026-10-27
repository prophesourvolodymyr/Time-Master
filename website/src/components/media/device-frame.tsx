import type { ReactNode } from "react";
import clsx from "clsx";
import styles from "./device-frame.module.css";

export type DeviceFrameProps = {
  children: ReactNode;
  className?: string;
};

export function DeviceFrame({ children, className }: DeviceFrameProps) {
  return (
    <div className={clsx(styles.device, className)}>
      <div className={styles.body}>
        <div className={styles.screen}>{children}</div>
        <span className={styles.island} aria-hidden="true" />
      </div>
    </div>
  );
}
