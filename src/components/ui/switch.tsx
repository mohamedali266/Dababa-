"use client";

import * as SwitchPrimitive from "@radix-ui/react-switch";
import type { ComponentPropsWithoutRef } from "react";
import { cn } from "@/lib/utils";

export function Switch({ className, ...props }: ComponentPropsWithoutRef<typeof SwitchPrimitive.Root>) {
  return (
    <SwitchPrimitive.Root
      className={cn(
        "relative h-7 w-12 rounded-full bg-surface-2 transition data-[state=checked]:bg-accent",
        className,
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb className="block size-5 translate-x-1 rounded-full bg-text shadow transition data-[state=checked]:translate-x-6 data-[state=checked]:bg-on-accent rtl:data-[state=checked]:-translate-x-6" />
    </SwitchPrimitive.Root>
  );
}
