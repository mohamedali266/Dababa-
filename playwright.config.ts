import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 2 : 0,
  reporter: "html",
  use: {
    baseURL: "http://127.0.0.1:3100",
    trace: "on-first-retry",
  },
  webServer: {
    command: "npm run dev -- --port 3100",
    url: "http://127.0.0.1:3100/ar",
    reuseExistingServer: !process.env.CI,
    timeout: 180_000,
  },
  projects: [
    { name: "ar-mobile-dark", use: { ...devices["Pixel 5"], colorScheme: "dark", locale: "ar-EG" } },
    { name: "en-desktop-light", use: { ...devices["Desktop Chrome"], colorScheme: "light", locale: "en-US" } },
  ],
});
