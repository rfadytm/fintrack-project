import { createContext, useContext, useState, type ReactNode } from "react";
import { currentPeriod, type Period } from "../utils/dateHelpers";

interface AppContextValue {
  period: Period;
  setPeriod: React.Dispatch<React.SetStateAction<Period>>;
}

const AppContext = createContext<AppContextValue | null>(null);

export function AppProvider({ children }: { children: ReactNode }) {
  const [period, setPeriod] = useState<Period>(currentPeriod());
  return <AppContext.Provider value={{ period, setPeriod }}>{children}</AppContext.Provider>;
}

export function useApp(): AppContextValue {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error("useApp must be used within AppProvider");
  return ctx;
}
