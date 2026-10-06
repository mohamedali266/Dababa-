import { ArrowUpRight, Dumbbell, ShieldCheck, Smartphone } from "lucide-react";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { DababaLogo } from "@/components/brand/logo";
import { CountUp } from "@/components/motion/count-up";
import { PageTransition } from "@/components/motion/page-transition";
import { StaggerItem, StaggerList } from "@/components/motion/stagger";
import { Badge } from "@/components/ui/badge";
import { Link } from "@/i18n/navigation";
import type { AppLocale } from "@/i18n/routing";

export default async function HomePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  const safeLocale = locale as AppLocale;
  setRequestLocale(safeLocale);
  const t = await getTranslations();

  return (
    <PageTransition>
      <main className="mx-auto flex min-h-dvh w-full max-w-6xl flex-col px-5 py-6 sm:px-8 lg:px-10">
        <header className="flex items-center justify-between gap-4">
          <DababaLogo locale={safeLocale} />
          <Link href="/design-system" className="rounded-full border border-[var(--border)] bg-surface px-4 py-3 text-sm font-extrabold">
            {t("nav.designSystem")}
          </Link>
        </header>

        <section className="grid flex-1 items-center gap-10 py-12 lg:grid-cols-[1.1fr_0.9fr]">
          <div>
            <Badge className="bg-surface text-accent-text">{t("home.eyebrow")}</Badge>
            <h1 className="mt-5 max-w-3xl text-5xl font-extrabold leading-[1.05] sm:text-6xl lg:text-7xl">
              {t("home.title")}
            </h1>
            <p className="mt-6 max-w-2xl text-lg leading-9 text-text-muted">{t("home.body")}</p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link
                href="/design-system"
                className="inline-flex min-h-13 items-center justify-center gap-2 rounded-full bg-accent px-7 text-base font-extrabold text-on-accent transition hover:brightness-95 active:scale-[0.98]"
              >
                {t("home.primaryAction")}
                <ArrowUpRight className="size-4 rtl-flip" />
              </Link>
            </div>
          </div>

          <StaggerList className="grid gap-4">
            {[
              { icon: Smartphone, label: t("home.statMembers"), value: 128 },
              { icon: Dumbbell, label: t("home.statClubs"), value: 2 },
              { icon: ShieldCheck, label: t("home.statUptime"), value: 100 },
            ].map((item) => (
              <StaggerItem key={item.label} className="rounded-[2rem] border border-[var(--border)] bg-surface p-6 shadow-[var(--shadow)]">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="text-sm font-bold text-text-muted">{item.label}</p>
                    <p className="mt-3 text-5xl font-extrabold tabular-nums">
                      <CountUp value={item.value} />
                    </p>
                  </div>
                  <span className="grid size-12 place-items-center rounded-full bg-accent text-on-accent">
                    <item.icon className="size-5" />
                  </span>
                </div>
              </StaggerItem>
            ))}
          </StaggerList>
        </section>
      </main>
    </PageTransition>
  );
}
