import { cn } from "@/lib/utils";

type LogoProps = {
  locale: "ar" | "en";
  className?: string;
};

export function DababaLogo({ locale, className }: LogoProps) {
  const primary = locale === "ar" ? "دبابة" : "Dababa";
  const secondary = locale === "ar" ? "Dababa" : "دبابة";

  return (
    <div className={cn("inline-flex items-center gap-3", className)}>
      <span className="relative grid size-12 place-items-center rounded-full bg-accent text-on-accent shadow-[inset_0_0_0_9px_color-mix(in_oklab,var(--on-accent)_16%,transparent)]">
        <span className="size-5 rounded-full border-[5px] border-current" />
      </span>
      <span className="grid leading-none">
        <span className="text-2xl font-extrabold tracking-normal">{primary}</span>
        <span className="mt-1 text-xs font-medium uppercase tracking-[0.14em] text-text-muted">{secondary}</span>
      </span>
    </div>
  );
}
