import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";

// B5: cek session via /api/auth/me (cookie httpOnly tak terbaca JS).
export default function ProtectedRoute() {
  const { loading, loggedIn } = useAuth();
  if (loading) return <div className="min-h-screen flex items-center justify-center text-muted">Memuat…</div>;
  return loggedIn ? <Outlet /> : <Navigate to="/login" replace />;
}
