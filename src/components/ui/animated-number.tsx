import { motion, useMotionValue, useTransform, animate } from "framer-motion";
import { useEffect, useRef, useState } from "react";

interface AnimatedNumberProps {
  // number | null: several call sites pass fields masked to null for
  // unauthenticated public-demo viewers (see shared/masking.py). Already
  // handled safely below via Number.isFinite(value) falling back to 0.
  value: number | null;
  format?: (n: number) => string;
  duration?: number;
  className?: string;
}

function prefersReducedMotion() {
  return typeof window !== "undefined" && !!window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
}

/** Angka bergulir dari nilai sebelumnya (0 saat pertama render) ke `value`.
 * MotionValue di-bind langsung sebagai children `motion.span` supaya tiap
 * frame update DOM langsung tanpa re-render React. Kalau OS/browser minta
 * prefers-reduced-motion (atau di lingkungan test tanpa rAF), langsung
 * render angka akhir tanpa animasi. */
export function AnimatedNumber({ value, format, duration = 0.9, className }: AnimatedNumberProps) {
  const target = typeof value === "number" && Number.isFinite(value) ? value : 0;
  const formatFn = format ?? ((n: number) => Math.round(n).toLocaleString("id-ID"));
  const motionValue = useMotionValue(0);
  const rounded = useTransform(motionValue, formatFn);
  const first = useRef(true);
  const [reduced] = useState(prefersReducedMotion);

  useEffect(() => {
    if (reduced) return;
    const controls = animate(motionValue, target, {
      duration: first.current ? duration : Math.min(duration, 0.6),
      ease: "easeOut",
    });
    first.current = false;
    return controls.stop;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target, reduced]);

  if (reduced) {
    return <span className={className}>{formatFn(target)}</span>;
  }
  return <motion.span className={className}>{rounded}</motion.span>;
}
