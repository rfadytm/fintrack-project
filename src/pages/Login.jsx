export default function Login() {
  return (
    <div className="center login">
      <div className="card login-card">
        <img src="/logo.jpg" alt="FinTrack" className="login-logo" />
        <h1>FinTrack</h1>
        <p>Login lewat Telegram untuk keamanan.</p>
        <ol>
          <li>Buka bot Telegram FinTrack kamu.</li>
          <li>
            Ketik <code>/getlink</code>.
          </li>
          <li>Klik link yang dikirim bot (berlaku 60 menit).</li>
        </ol>
        <p className="muted">Tidak ada password — bot adalah faktor autentikasi kamu.</p>
      </div>
    </div>
  );
}
