import * as React from "react";
import { cn } from "../../lib/utils";

// Native <select>, Tailwind-styled — simpler and no worse accessibility than a
// custom Radix listbox for this app's plain option lists.
const Select = React.forwardRef<HTMLSelectElement, React.SelectHTMLAttributes<HTMLSelectElement>>(
  ({ className, children, ...props }, ref) => (
    <select
      ref={ref}
      className={cn(
        "flex h-9 w-full rounded-lg border border-border bg-white/5 px-3 py-1 text-sm text-white shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue/50 disabled:cursor-not-allowed disabled:opacity-50 [&>option]:bg-[#16161a] [&>option]:text-white",
        className
      )}
      {...props}
    >
      {children}
    </select>
  )
);
Select.displayName = "Select";

export { Select };
