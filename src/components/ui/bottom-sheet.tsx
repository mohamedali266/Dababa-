"use client";

import * as DialogPrimitive from "@radix-ui/react-dialog";
import type { ComponentPropsWithoutRef } from "react";
import { cn } from "@/lib/utils";

export const BottomSheet = DialogPrimitive.Root;
export const BottomSheetTrigger = DialogPrimitive.Trigger;

export function BottomSheetContent({
  className,
  children,
  ...props
}: ComponentPropsWithoutRef<typeof DialogPrimitive.Content>) {
  return (
    <DialogPrimitive.Portal>
      <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-black/55" />
      <DialogPrimitive.Content
        className={cn(
          "fixed inset-x-0 bottom-0 z-50 rounded-t-[2rem] border border-[var(--border)] bg-surface p-6 pb-[calc(1.5rem+env(safe-area-inset-bottom))] text-text shadow-[var(--shadow)]",
          className,
        )}
        {...props}
      >
        <div className="mx-auto mb-5 h-1.5 w-12 rounded-full bg-surface-2" />
        {children}
      </DialogPrimitive.Content>
    </DialogPrimitive.Portal>
  );
}
