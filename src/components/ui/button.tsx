import { cva, type VariantProps } from "class-variance-authority";
import type { ButtonHTMLAttributes } from "react";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex min-h-11 items-center justify-center gap-2 rounded-full px-5 text-sm font-extrabold transition duration-150 ease-out disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        primary: "bg-accent text-on-accent hover:brightness-95 active:scale-[0.98]",
        secondary: "border border-[var(--border)] bg-surface text-text hover:bg-surface-2 active:scale-[0.98]",
        ghost: "text-text hover:bg-surface-2 active:scale-[0.98]",
        danger: "bg-danger text-bg hover:brightness-95 active:scale-[0.98]",
      },
      size: {
        sm: "min-h-10 px-4 text-xs",
        md: "min-h-11 px-5",
        lg: "min-h-13 px-7 text-base",
        icon: "size-11 px-0",
      },
    },
    defaultVariants: {
      size: "md",
      variant: "primary",
    },
  },
);

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & VariantProps<typeof buttonVariants>;

export function Button({ className, size, variant, ...props }: ButtonProps) {
  return <button className={cn(buttonVariants({ size, variant }), className)} {...props} />;
}
