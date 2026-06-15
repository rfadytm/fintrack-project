import { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { api } from "../utils/api";

// /auth?t=TOKEN — tukar token jadi session cookie lalu redirect ke dashboard.
export default function AuthCallback() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const [error, setError] = useState(null);

  useEffect(() => {
    const token = params.get("t");
    if (!token) {
      setError("Token tidak ada.");
      return;
    }
    api
      .verify(token)
      .then(() => navigate("/dashboard", { replace: true }))
      .catch((e) => setError(e.message === "unauthorized" ? "Token invalid / expired." : e.message));
  }, [params, navigate]);

  return (
    <div className="center">
      {error ? (
        <div className="card">
          <p className="error">⚠️ {error}</p>
          <p className="muted">Minta link baru: ketik /getlink di Telegram.</p>
        </div>
      ) : (
        <p className="muted">Memverifikasi…</p>
      )}
    </div>
  );
}
