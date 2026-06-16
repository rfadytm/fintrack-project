import { BrowserRouter, Navigate, Outlet, Route, Routes } from "react-router-dom";
import Navbar from "./components/Navbar";
import ProtectedRoute from "./components/ProtectedRoute";
import { AppProvider } from "./context/AppContext";
import AuthCallback from "./pages/AuthCallback";
import COA from "./pages/COA";
import Dashboard from "./pages/Dashboard";
import Journal from "./pages/Journal";
import Ledger from "./pages/Ledger";
import Login from "./pages/Login";
import Reports from "./pages/Reports";
import Settings from "./pages/Settings";

function Layout() {
  return (
    <AppProvider>
      <Navbar />
      <main className="content">
        <Outlet />
      </main>
      <footer className="footer">
        © {new Date().getFullYear()} FinTrack — dev Rafi
      </footer>
    </AppProvider>
  );
}

export default function App() {
  return (
    <BrowserRouter>
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
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
          </Route>
        </Route>
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
