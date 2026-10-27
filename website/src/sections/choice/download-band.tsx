import Image from "next/image";
import { DownloadButtons } from "@/components/downloads/download-buttons";
import styles from "./choice.module.css";

export function DownloadBand() {
  return (
    <div id="download" className={styles.band}>
      <div className={styles.bandArt}>
        <Image src="/media/choice/download-hand.webp" alt="" fill sizes="(max-width: 1180px) 100vw, 1180px" />
      </div>
      <div className="flex flex-col gap-6 p-6 md:max-w-[62%] md:p-9">
        <h3 className="text-display text-[clamp(30px,3.4vw,48px)]">
          Skip the tour. <span className="text-accent">Start training.</span>
        </h3>
        <DownloadButtons />
      </div>
    </div>
  );
}
