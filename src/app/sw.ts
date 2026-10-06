import { Serwist, type PrecacheEntry } from "serwist";

declare const self: typeof globalThis & {
  __SW_MANIFEST: (PrecacheEntry | string)[];
};

const serwist = new Serwist({
  precacheEntries: self.__SW_MANIFEST,
  skipWaiting: true,
  clientsClaim: true,
  navigationPreload: true,
  fallbacks: {
    entries: [
      {
        matcher({ request }) {
          return request.destination === "document";
        },
        url: "/ar/offline",
      },
    ],
  },
});

serwist.addEventListeners();
