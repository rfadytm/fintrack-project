import "@testing-library/jest-dom/vitest";

// jsdom's matchMedia stub always reports matches:false (and warns "not implemented").
// AnimatedNumber checks prefers-reduced-motion to decide whether to animate; force it
// reduced here so number displays in tests render their final value immediately
// instead of the count-up animation.
if (typeof window !== "undefined") {
  window.matchMedia = ((query: string) => ({
    matches: query.includes("prefers-reduced-motion"),
    media: query,
    onchange: null,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => false,
  })) as unknown as typeof window.matchMedia;
}

// jsdom has no ResizeObserver — Recharts' <ResponsiveContainer> (used by
// CategoryChart/TimelineChart) needs one to measure its box on mount.
if (typeof globalThis.ResizeObserver === "undefined") {
  globalThis.ResizeObserver = class ResizeObserver {
    observe() {}
    unobserve() {}
    disconnect() {}
  } as unknown as typeof ResizeObserver;
}
