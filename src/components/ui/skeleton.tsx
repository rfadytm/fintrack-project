import { cn } from "../../lib/utils";

function Skeleton({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn("animate-pulse rounded-lg bg-white/[0.03] border border-white/[0.05]", className)}
      {...props}
    />
  );
}

export { Skeleton };
