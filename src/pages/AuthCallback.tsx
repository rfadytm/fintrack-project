import { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { api } from "../utils/api";
import { queryClient } from "../lib/queryClient";
import { Card } from "../components/ui/card";

// /auth?t=TOKEN — tukar token jadi session cookie lalu redirect ke dashboard.
export default function AuthCallback() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = params.get("t");
    if (!token) {
      setError("Token tidak ada.");
      return;
    }
    api
      .verify(token)
      .then(async () => {
        // Force ProtectedRoute's useAuth query to refetch — otherwise the
        // pre-login "not logged in" result could still be considered fresh.
        await queryClient.invalidateQueries({ queryKey: ["auth"] });
        navigate("/dashboard", { replace: true });
      })
      .catch((e: Error) => setError(e.message === "unauthorized" ? "Token invalid / expired." : e.message));
  }, [params, navigate]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-50 via-blue-50/50 to-indigo-100 p-6">
      {error ? (
        <Card className="text-center max-w-sm">
          <p className="text-red">⚠️ {error}</p>
          <p className="text-muted text-sm">Minta link baru: ketik /getlink di Telegram.</p>
        </Card>
      ) : (
        <p className="text-muted">Memverifikasi…</p>
      )}
    </div>
  );
}
