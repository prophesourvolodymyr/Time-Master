import Image from "next/image";
import clsx from "clsx";
import { DownloadButtons } from "@/components/downloads/download-buttons";
import styles from "./install-banner.module.css";

export type InstallBannerProps = {
  heading: "h2" | "h3";
  titleId?: string;
  className?: string;
};

export function InstallBanner({ heading: Heading, titleId, className }: InstallBannerProps) {
  return (
    <div className={clsx(styles.banner, className)}>
      <div className={styles.art} aria-hidden="true">
        <Image src="/media/choice/download-hand.webp" alt="" fill sizes="(max-width: 1080px) 100vw, 1080px" />
      </div>
      <div className={styles.body}>
        <Heading id={titleId} className="text-display text-[clamp(32px,4vw,56px)]">
          Skip the tour. <span className="text-accent">Start training.</span>
        </Heading>
        <p className="max-w-[38ch] text-[15px] text-ink-2">Tmax on your phone, your Mac and every screen you train with.</p>
        <DownloadButtons />
      </div>
    </div>
  );
}
