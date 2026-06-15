import { createContext, useContext, useState } from "react";
import { currentPeriod } from "../utils/dateHelpers";

const AppContext = createContext(null);

export function AppProvider({ children }) {
  const [period, setPeriod] = useState(currentPeriod());
  return (
    <AppContext.Provider value={{ period, setPeriod }}>
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  return useContext(AppContext);
}
