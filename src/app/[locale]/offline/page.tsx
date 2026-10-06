import { WifiOff } from "lucide-react";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { EmptyState } from "@/components/ui/empty-state";

export default async function OfflinePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("offline");

  return (
    <main className="grid min-h-dvh place-items-center p-5">
      <div className="w-full max-w-xl">
        <div className="mb-5 grid size-14 place-items-center rounded-full bg-accent text-on-accent">
          <WifiOff className="size-6" />
        </div>
        <EmptyState title={t("title")} body={t("body")} />
      </div>
    </main>
  );
}
