import { lazy, Suspense, useEffect } from "react";
import {
  BrowserRouter,
  Navigate,
  Outlet,
  Route,
  Routes,
  useLocation,
  useNavigate,
} from "react-router-dom";
import { QueryClientProvider } from "@tanstack/react-query";
import { AnimatePresence, motion } from "framer-motion";
import { Toaster } from "sonner";
import Navbar from "./components/Navbar";
import ProtectedRoute from "./components/ProtectedRoute";
import { ErrorBoundary } from "./components/ErrorBoundary";
import AppBackground from "./components/AppBackground";
import { Skeleton } from "./components/ui/skeleton";
import { AppProvider } from "./context/AppContext";
import { queryClient, setUnauthorizedHandler } from "./lib/queryClient";
import Login from "./pages/Login";
import AuthCallback from "./pages/AuthCallback";

// Code-split the protected pages: they pull in recharts/xlsx/framer-motion-heavy
// UI and don't need to be in the initial bundle the (unauthenticated) Login page ships.
const Dashboard = lazy(() => import("./pages/Dashboard"));
const Journal = lazy(() => import("./pages/Journal"));
const Ledger = lazy(() => import("./pages/Ledger"));
const Reports = lazy(() => import("./pages/Reports"));
const COA = lazy(() => import("./pages/COA"));
const Settings = lazy(() => import("./pages/Settings"));
const Budgets = lazy(() => import("./pages/Budgets"));
const Goals = lazy(() => import("./pages/Goals"));
const Recurring = lazy(() => import("./pages/Recurring"));
const Bills = lazy(() => import("./pages/Bills"));

// Wires an expired/invalid session (any query throwing UnauthorizedError) to a
// redirect — see the blindspot note in lib/queryClient.ts.
function AuthErrorHandler() {
  const navigate = useNavigate();
  useEffect(() => {
    setUnauthorizedHandler(() => navigate("/login", { replace: true }));
    return () => setUnauthorizedHandler(null);
  }, [navigate]);
  return null;
}

function Layout() {
  const location = useLocation();
  return (
    <AppProvider>
      <AppBackground />
      <div className="min-h-screen flex flex-col">
        <Navbar />
        <main className="flex-1 w-full max-w-[1100px] mx-auto p-4 sm:p-6">
          <AnimatePresence mode="wait">
            <motion.div
              key={location.pathname}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.2 }}
            >
              <Suspense fallback={<Skeleton className="h-64" />}>
                <Outlet />
              </Suspense>
            </motion.div>
          </AnimatePresence>
        </main>
        <footer className="text-center py-4 text-xs text-muted border-t border-white/30 bg-white/30 backdrop-blur-md">
          © {new Date().getFullYear()} FinTrack — dev Rafi
        </footer>
      </div>
    </AppProvider>
  );
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ErrorBoundary>
        <BrowserRouter>
          <AuthErrorHandler />
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/auth" element={<AuthCallback />} />
            <Route element={<ProtectedRoute />}>
              <Route element={<Layout />}>
                <Route path="/dashboard" element={<Dashboard />} />
                <Route path="/journal" element={<Journal />} />
                <Route path="/ledger" element={<Ledger />} />
                <Route path="/reports" element={<Reports />} />
                <Route path="/coa" element={<COA />} />
                <Route path="/settings" element={<Settings />} />
                <Route path="/budgets" element={<Budgets />} />
                <Route path="/goals" element={<Goals />} />
                <Route path="/recurring" element={<Recurring />} />
                <Route path="/bills" element={<Bills />} />
                <Route path="/" element={<Navigate to="/dashboard" replace />} />
              </Route>
            </Route>
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </BrowserRouter>
        <Toaster richColors position="top-center" />
      </ErrorBoundary>
    </QueryClientProvider>
  );
}
