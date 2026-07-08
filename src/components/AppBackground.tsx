// Glassmorphism only reads as "glass" when there's something colorful behind
// the blur for it to frost. A flat pastel page (the old body background) gives
// backdrop-blur nothing to do. These fixed, decorative blobs sit behind every
// page so Card/Navbar's backdrop-blur has real contrast to work with.
export default function AppBackground() {
  return (
    <div aria-hidden className="fixed inset-0 -z-10 overflow-hidden bg-slate-50">
      <div className="absolute -top-32 -left-32 h-[26rem] w-[26rem] rounded-full bg-blue-400/50 blur-3xl" />
      <div className="absolute top-1/4 -right-40 h-[30rem] w-[30rem] rounded-full bg-indigo-400/40 blur-3xl" />
      <div className="absolute bottom-[-8rem] left-1/4 h-96 w-96 rounded-full bg-navy/30 blur-3xl" />
      <div className="absolute bottom-0 right-1/4 h-72 w-72 rounded-full bg-blue-300/40 blur-3xl" />
    </div>
  );
}
