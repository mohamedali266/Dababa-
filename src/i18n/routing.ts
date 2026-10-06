import { defineRouting } from "next-intl/routing";

export const locales = ["ar", "en"] as const;
export type AppLocale = (typeof locales)[number];

export const localeMeta: Record<AppLocale, { dir: "rtl" | "ltr"; label: string }> = {
  ar: { dir: "rtl", label: "العربية" },
  en: { dir: "ltr", label: "English" },
};

export const routing = defineRouting({
  defaultLocale: "ar",
  localePrefix: "always",
  locales,
});
