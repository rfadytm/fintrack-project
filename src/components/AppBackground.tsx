// Apple obsidian glassmorphism: a deep dark canvas with soft, low-opacity
// ambient glow blobs behind everything, so Card's backdrop-blur has real
// (but subtle) contrast to frost — not a flat black void, not a bright
// pastel page like the old light theme.
export default function AppBackground() {
  return (
    <div aria-hidden className="fixed inset-0 -z-10 overflow-hidden bg-[#09090b]">
      <div className="absolute -top-32 -left-32 h-[28rem] w-[28rem] rounded-full bg-indigo-500/10 blur-[150px]" />
      <div className="absolute top-1/4 -right-40 h-[32rem] w-[32rem] rounded-full bg-emerald-500/10 blur-[150px]" />
      <div className="absolute bottom-[-8rem] left-1/4 h-96 w-96 rounded-full bg-blue-500/10 blur-[150px]" />
    </div>
  );
}
