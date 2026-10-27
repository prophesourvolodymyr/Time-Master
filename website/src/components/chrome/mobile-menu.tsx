"use client";

import { useEffect, useRef } from "react";
import { XIcon } from "@phosphor-icons/react";
import { DownloadButtons } from "@/components/downloads/download-buttons";
import { IconButton } from "@/components/ui";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { navLinks, type NavLink } from "./nav-links";
import { TmaxMark } from "./tmax-mark";
import styles from "./nav-bar.module.css";

export type MobileMenuProps = {
  open: boolean;
  onClose: () => void;
  onNavigate: (link: NavLink) => void;
};

export function MobileMenu({ open, onClose, onNavigate }: MobileMenuProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const { stop, start } = useSmoothScroll();

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (open && !dialog.open) {
      dialog.showModal();
      stop();
    }
    if (!open && dialog.open) {
      dialog.close();
      start();
    }
  }, [open, stop, start]);

  return (
    <dialog ref={dialogRef} className={styles.sheet} aria-label="Menu" onClose={onClose}>
      <div className="flex h-full flex-col px-5 pb-8">
        <div className="flex h-[var(--nav-height)] items-center justify-between">
          <TmaxMark className="h-7 w-auto" />
          <IconButton label="Close menu" icon={<XIcon size={22} weight="bold" />} onClick={onClose} />
        </div>
        <ul className="mt-8 flex flex-col gap-2">
          {navLinks.map((link) => (
            <li key={link.label}>
              <button type="button" className="w-full py-2 text-left font-display text-[44px] leading-none font-black tracking-tight" onClick={() => onNavigate(link)}>
                {link.label}
              </button>
            </li>
          ))}
        </ul>
        <DownloadButtons stacked className="mt-auto" />
      </div>
    </dialog>
  );
}
