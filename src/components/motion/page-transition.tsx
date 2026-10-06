"use client";

import { motion } from "motion/react";
import type { ReactNode } from "react";
import { motionTokens } from "@/lib/motion";

export function PageTransition({ children }: { children: ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: motionTokens.duration.slow, ease: motionTokens.easeOut }}
    >
      {children}
    </motion.div>
  );
}
