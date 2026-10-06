import { Bell, Moon, Sun } from "lucide-react";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

export default async function DesignSystemPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations();

  return (
    <main className="mx-auto min-h-dvh w-full max-w-6xl px-5 py-8 sm:px-8">
      <header className="mb-8 max-w-3xl">
        <Badge className="bg-accent text-on-accent">Dababa</Badge>
        <h1 className="mt-5 text-4xl font-extrabold sm:text-5xl">{t("design.title")}</h1>
        <p className="mt-4 text-base leading-8 text-text-muted">{t("design.body")}</p>
      </header>

      <div className="grid gap-5 lg:grid-cols-2">
        <section className="rounded-[2rem] bg-surface p-6">
          <h2 className="mb-4 text-xl font-extrabold">{t("design.buttons")}</h2>
          <div className="flex flex-wrap gap-3">
            <Button>{t("common.save")}</Button>
            <Button variant="secondary">{t("common.cancel")}</Button>
            <Button variant="ghost" size="icon" aria-label={t("common.theme")}>
              <Sun className="size-5" />
            </Button>
            <Button variant="secondary" size="icon" aria-label={t("common.theme")}>
              <Moon className="size-5" />
            </Button>
          </div>
        </section>

        <section className="rounded-[2rem] bg-surface p-6">
          <h2 className="mb-4 text-xl font-extrabold">{t("design.forms")}</h2>
          <div className="grid gap-4">
            <label className="grid gap-2 text-sm font-extrabold">
              {t("design.sampleLabel")}
              <Input defaultValue={t("design.memberName")} />
            </label>
            <Select defaultValue="monthly">
              <SelectTrigger>
                <SelectValue placeholder={t("design.selectPlaceholder")} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="monthly">{t("design.optionMonthly")}</SelectItem>
                <SelectItem value="quarter">{t("design.optionQuarter")}</SelectItem>
              </SelectContent>
            </Select>
            <div className="flex items-center gap-4">
              <Checkbox defaultChecked aria-label="checked" />
              <Switch defaultChecked aria-label="enabled" />
            </div>
          </div>
        </section>

        <section className="rounded-[2rem] bg-surface p-6">
          <h2 className="mb-4 text-xl font-extrabold">{t("design.feedback")}</h2>
          <div className="grid gap-4">
            <Skeleton className="h-14" />
            <EmptyState title={t("common.emptyTitle")} body={t("common.emptyBody")} />
          </div>
        </section>

        <section className="rounded-[2rem] bg-surface p-6">
          <h2 className="mb-4 text-xl font-extrabold">{t("design.tabs")}</h2>
          <Tabs defaultValue="one">
            <TabsList>
              <TabsTrigger value="one">{t("design.buttons")}</TabsTrigger>
              <TabsTrigger value="two">{t("design.forms")}</TabsTrigger>
            </TabsList>
            <TabsContent value="one">
              <Dialog>
                <DialogTrigger asChild>
                  <Button>
                    <Bell className="size-4" />
                    {t("common.open")}
                  </Button>
                </DialogTrigger>
                <DialogContent>
                  <DialogTitle>{t("design.dialogTitle")}</DialogTitle>
                  <DialogDescription>{t("design.dialogBody")}</DialogDescription>
                </DialogContent>
              </Dialog>
            </TabsContent>
            <TabsContent value="two">
              <p className="text-sm leading-7 text-text-muted">{t("common.loading")}</p>
            </TabsContent>
          </Tabs>
        </section>
      </div>
    </main>
  );
}
