"use client";

import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

type ImmersiveState = {
  immersive: boolean;
  acquire: () => () => void;
};

const ImmersiveContext = createContext<ImmersiveState | null>(null);

export function ImmersiveProvider({ children }: { children: ReactNode }) {
  const [holders, setHolders] = useState(0);
  const value = useMemo<ImmersiveState>(
    () => ({
      immersive: holders > 0,
      acquire: () => {
        setHolders((count) => count + 1);
        return () => setHolders((count) => Math.max(0, count - 1));
      },
    }),
    [holders],
  );
  return <ImmersiveContext.Provider value={value}>{children}</ImmersiveContext.Provider>;
}

function useImmersiveContext() {
  const context = useContext(ImmersiveContext);
  if (!context) throw new Error("Immersive hooks must be used inside ImmersiveProvider");
  return context;
}

export function useImmersive(active: boolean) {
  const { acquire } = useImmersiveContext();
  useEffect(() => (active ? acquire() : undefined), [active, acquire]);
}

export function useIsImmersive() {
  return useImmersiveContext().immersive;
}
