"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { XIcon } from "@phosphor-icons/react";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { IconButton } from "@/components/ui";
import { InstallBanner } from "./install-banner";
import styles from "./install-sheet.module.css";

type InstallState = {
  openInstall: () => void;
};

const InstallContext = createContext<InstallState | null>(null);

export function InstallProvider({ children }: { children: ReactNode }) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [open, setOpen] = useState(false);
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

  const openInstall = useCallback(() => setOpen(true), []);
  const value = useMemo(() => ({ openInstall }), [openInstall]);

  return (
    <InstallContext.Provider value={value}>
      {children}
      <dialog
        ref={dialogRef}
        className={styles.sheet}
        aria-labelledby="install-title"
        onClose={() => {
          setOpen(false);
          start();
        }}
        onClick={(event) => {
          if (event.target === event.currentTarget) setOpen(false);
        }}
      >
        <div className={styles.panel}>
          <span className={styles.grabber} aria-hidden="true" />
          <InstallBanner heading="h2" titleId="install-title" className={styles.content} />
          <IconButton className={styles.close} label="Close" icon={<XIcon weight="bold" />} onClick={() => setOpen(false)} />
        </div>
      </dialog>
    </InstallContext.Provider>
  );
}

export function useInstall() {
  const context = useContext(InstallContext);
  if (!context) throw new Error("useInstall must be used inside InstallProvider");
  return context;
}
