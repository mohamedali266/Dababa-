"use client";

import * as ToastPrimitive from "@radix-ui/react-toast";
import type { ComponentPropsWithoutRef } from "react";
import { cn } from "@/lib/utils";

export const ToastProvider = ToastPrimitive.Provider;
export const Toast = ToastPrimitive.Root;
export const ToastTitle = ToastPrimitive.Title;
export const ToastDescription = ToastPrimitive.Description;

export function ToastViewport(props: ComponentPropsWithoutRef<typeof ToastPrimitive.Viewport>) {
  return (
    <ToastPrimitive.Viewport
      className="fixed bottom-4 end-4 z-[100] flex w-[min(calc(100vw-2rem),24rem)] flex-col gap-3"
      {...props}
    />
  );
}

export function ToastFrame({ className, ...props }: ComponentPropsWithoutRef<typeof ToastPrimitive.Root>) {
  return (
    <ToastPrimitive.Root
      className={cn("rounded-2xl border border-[var(--border)] bg-surface p-4 text-sm font-bold shadow-[var(--shadow)]", className)}
      {...props}
    />
  );
}
