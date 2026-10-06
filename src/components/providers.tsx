"use client";

import { MotionConfig } from "motion/react";
import { ThemeProvider } from "next-themes";
import type { ReactNode } from "react";
import { ToastProvider, ToastViewport } from "@/components/ui/toast";
import { motionTokens } from "@/lib/motion";

export function Providers({ children }: { children: ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="dark" enableSystem disableTransitionOnChange>
      <MotionConfig reducedMotion="user" transition={{ duration: motionTokens.duration.base, ease: motionTokens.easeOut }}>
        <ToastProvider>
          {children}
          <ToastViewport />
        </ToastProvider>
      </MotionConfig>
    </ThemeProvider>
  );
}
