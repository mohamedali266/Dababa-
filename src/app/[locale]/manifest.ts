import type { MetadataRoute } from "next";
import type { AppLocale } from "@/i18n/routing";

export default async function manifest({ params }: { params: Promise<{ locale: string }> }): Promise<MetadataRoute.Manifest> {
  const { locale } = await params;
  const safeLocale: AppLocale = locale === "en" ? "en" : "ar";

  return {
    name: safeLocale === "ar" ? "دبابة" : "Dababa",
    short_name: safeLocale === "ar" ? "دبابة" : "Dababa",
    description: safeLocale === "ar" ? "تطبيق إدارة الجيم والعضويات" : "Gym management and membership app",
    start_url: `/${safeLocale}`,
    scope: "/",
    display: "standalone",
    background_color: "#1d211f",
    theme_color: "#c6f432",
    orientation: "portrait",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png", purpose: "maskable" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
      { src: "/icons/apple-touch-icon.png", sizes: "180x180", type: "image/png" }
    ],
  };
}
