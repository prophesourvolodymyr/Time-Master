import type { ReactNode } from "react";
import clsx from "clsx";
import { siApple, siGoogleplay } from "simple-icons";
import { DownloadSimpleIcon } from "@phosphor-icons/react/ssr";
import { ActionButton } from "@/components/ui";
import { downloads, type DownloadId } from "@/lib/site";

function BrandGlyph({ path }: { path: string }) {
  return (
    <svg viewBox="0 0 24 24" width="1em" height="1em" fill="currentColor" aria-hidden="true">
      <path d={path} />
    </svg>
  );
}

const glyphs: Record<DownloadId, ReactNode> = {
  appStore: <BrandGlyph path={siApple.path} />,
  googlePlay: <BrandGlyph path={siGoogleplay.path} />,
  ipa: <DownloadSimpleIcon weight="bold" />,
};

const captions: Record<DownloadId, string> = {
  appStore: "Download on the",
  googlePlay: "Get it on",
  ipa: "Direct install",
};

export type DownloadButtonsProps = {
  className?: string;
  stacked?: boolean;
};

export function DownloadButtons({ className, stacked = false }: DownloadButtonsProps) {
  return (
    <ul className={clsx("flex gap-3", stacked ? "flex-col" : "flex-wrap", className)}>
      {downloads.map((download) => {
        const caption = download.href ? captions[download.id] : "Coming soon";
        return (
          <li key={download.id} className={clsx(stacked && "w-full")}>
            <ActionButton
              href={download.href}
              disabled={!download.href}
              prominent={download.id === "appStore"}
              size={58}
              paddingX={20}
              fillsWidth={stacked}
              font="inherit"
              icon={<span className="text-[22px]">{glyphs[download.id]}</span>}
              aria-label={`${download.label}, ${caption}`}
              rel={download.href ? "noopener" : undefined}
            >
              <span className="flex flex-col items-start gap-1 text-left">
                <span className="font-body text-[11px] font-normal tracking-wide text-ink-2">{caption}</span>
                <span className="text-[17px] tracking-tight">{download.label}</span>
              </span>
            </ActionButton>
          </li>
        );
      })}
    </ul>
  );
}
