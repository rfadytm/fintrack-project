import { motion } from "framer-motion";
import { Card } from "../components/ui/card";
import AppBackground from "../components/AppBackground";

export default function Login() {
  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <AppBackground />
      <motion.div
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
      >
        <Card className="max-w-sm text-center">
          <img src="/logo.png" alt="FinTrack" className="h-20 w-20 object-contain mx-auto mb-2" />
          <h1 className="text-navy text-2xl font-bold m-0">FinTrack</h1>
          <p className="text-sm mt-2">Login lewat Telegram untuk keamanan.</p>
          <ol className="text-left text-sm space-y-1 my-3 pl-5">
            <li>Buka bot Telegram FinTrack kamu.</li>
            <li>
              Ketik <code>/getlink</code>.
            </li>
            <li>Klik link yang dikirim bot (berlaku 60 menit).</li>
          </ol>
          <p className="text-muted text-sm">Tidak ada password — bot adalah faktor autentikasi kamu.</p>
        </Card>
      </motion.div>
    </div>
  );
}
