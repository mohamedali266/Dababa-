import type { InputHTMLAttributes } from "react";
import { cn } from "@/lib/utils";

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={cn(
        "min-h-12 w-full rounded-2xl border border-[var(--border)] bg-surface px-4 text-sm font-medium text-text shadow-sm transition placeholder:text-text-muted focus:border-accent focus:outline-none",
        className,
      )}
      {...props}
    />
  );
}
