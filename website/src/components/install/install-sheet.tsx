"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { XIcon } from "@phosphor-icons/react";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { IconButton } from "@/components/ui";
import { useMediaQuery } from "@/lib/motion";
import { InstallBanner } from "./install-banner";
import styles from "./install-sheet.module.css";

type InstallState = {
  openInstall: () => void;
};

const InstallContext = createContext<InstallState | null>(null);

const shownKey = "tmax-install-shown";
const autoShowDelay = 1200;

export function InstallProvider({ children }: { children: ReactNode }) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [open, setOpen] = useState(false);
  const notice = useMediaQuery("(min-width: 900px) and (pointer: fine)");
  const { stop, start } = useSmoothScroll();

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (open && !dialog.open) {
      if (notice) {
        dialog.show();
      } else {
        dialog.showModal();
        stop();
      }
    }
    if (!open && dialog.open) {
      dialog.close();
      start();
    }
  }, [open, notice, stop, start]);

  useEffect(() => {
    if (!open || !notice) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [open, notice]);

  useEffect(() => {
    if (!notice || sessionStorage.getItem(shownKey)) return;
    const target = document.getElementById("stats");
    if (!target) return;
    let timer = 0;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;
        observer.disconnect();
        timer = window.setTimeout(() => {
          if (sessionStorage.getItem(shownKey)) return;
          sessionStorage.setItem(shownKey, "1");
          setOpen(true);
        }, autoShowDelay);
      },
      { threshold: 0.2 },
    );
    observer.observe(target);
    return () => {
      observer.disconnect();
      window.clearTimeout(timer);
    };
  }, [notice]);

  const openInstall = useCallback(() => {
    sessionStorage.setItem(shownKey, "1");
    setOpen(true);
  }, []);
  const value = useMemo(() => ({ openInstall }), [openInstall]);

  return (
    <InstallContext.Provider value={value}>
      {children}
      <dialog
        ref={dialogRef}
        className={styles.sheet}
        data-variant={notice ? "notice" : "sheet"}
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
          {notice ? null : <span className={styles.grabber} aria-hidden="true" />}
          <InstallBanner heading="h2" titleId="install-title" layout={notice ? "stacked" : "wide"} className={styles.content} />
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
