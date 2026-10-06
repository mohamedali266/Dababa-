import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("renders Arabic home and design preview", async ({ page }) => {
  await page.goto("/ar");
  await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
  await expect(page.getByRole("heading", { name: /دبابة جاهزة للبناء/ })).toBeVisible();
  await page.goto("/ar/design-system");
  await expect(page.getByRole("heading", { name: /معاينة نظام دبابة/ })).toBeVisible();
});

test("renders English LTR with no serious axe issues", async ({ page }) => {
  await page.goto("/en");
  await expect(page.locator("html")).toHaveAttribute("dir", "ltr");
  await expect(page.getByRole("heading", { name: /Dababa is ready to build/ })).toBeVisible();
  await page.waitForTimeout(900);
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations).toEqual([]);
});
