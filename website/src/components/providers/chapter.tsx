"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { isChapterId, type ChapterId } from "@/lib/site";

export type ChapterRequest = {
  id: ChapterId;
  scroll: boolean;
  sequence: number;
  fromY: number;
};

type ChapterState = {
  chapter: ChapterId;
  request: ChapterRequest | null;
  selectChapter: (id: ChapterId, options?: { scroll?: boolean }) => void;
};

const ChapterContext = createContext<ChapterState | null>(null);

export function ChapterProvider({ children }: { children: ReactNode }) {
  const [request, setRequest] = useState<ChapterRequest | null>(null);
  const [chapter, setChapter] = useState<ChapterId>("ai");

  const selectChapter = useCallback((id: ChapterId, options: { scroll?: boolean } = {}) => {
    setChapter(id);
    const fromY = window.scrollY;
    setRequest((previous) => ({ id, scroll: options.scroll ?? false, sequence: (previous?.sequence ?? 0) + 1, fromY }));
    window.history.replaceState(window.history.state, "", `#${id}`);
  }, []);

  useEffect(() => {
    const fromHash = () => {
      const hash = window.location.hash.slice(1);
      if (isChapterId(hash)) selectChapter(hash, { scroll: true });
    };
    fromHash();
    window.addEventListener("hashchange", fromHash);
    return () => window.removeEventListener("hashchange", fromHash);
  }, [selectChapter]);

  const value = useMemo(() => ({ chapter, request, selectChapter }), [chapter, request, selectChapter]);
  return <ChapterContext.Provider value={value}>{children}</ChapterContext.Provider>;
}

export function useChapter() {
  const context = useContext(ChapterContext);
  if (!context) throw new Error("useChapter must be used inside ChapterProvider");
  return context;
}
