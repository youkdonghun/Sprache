'use strict';

const CACHE_PREFIX = 'sprache-pwa-';
const CACHE_NAME = `${CACHE_PREFIX}1.36.3-64-r1`;
const PRECACHE = [
  './',
  './index.html',
  './flutter_bootstrap.js',
  './flutter.js',
  './main.dart.js',
  './manifest.json',
  './version.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
  './sqlite3.wasm',
  './drift_worker.js',
  './canvaskit/canvaskit.js',
  './canvaskit/canvaskit.wasm',
  './canvaskit/chromium/canvaskit.js',
  './canvaskit/chromium/canvaskit.wasm',
  './assets/AssetManifest.bin',
  './assets/FontManifest.json',
  './assets/fonts/MaterialIcons-Regular.otf',
  './assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
  './assets/assets/fonts/NotoSansKR-Variable.ttf',
  './assets/assets/content/baseball-starter-pack-2026-07-28.json',
  './assets/assets/content/idol-fandom-starter-pack-2026-07-28.json',
  './assets/assets/content/tatoeba-korean-sentence-pack-2026-07-28.json',
  './assets/assets/content/tatoeba-practical-sentence-pack-2026-07-29.json',
  './assets/assets/templates/Sprache-easy-import-template.xlsx',
  './assets/assets/templates/Sprache-word-import-template.xlsx',
  './assets/packages/pdfrx/assets/pdfium.wasm',
  './assets/packages/pdfrx/assets/pdfium_client.js',
  './assets/packages/pdfrx/assets/pdfium_worker.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE)),
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      const previous = names.filter(
        (name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME,
      );
      await Promise.all(previous.map((name) => caches.delete(name)));
      await self.clients.claim();
      if (previous.length > 0) {
        const clients = await self.clients.matchAll({ type: 'window' });
        for (const client of clients) {
          client.postMessage({
            type: 'SPRACHE_UPDATE_READY',
            version: '1.36.3',
          });
        }
      }
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(async () => {
        const cache = await caches.open(CACHE_NAME);
        return (await cache.match('./index.html')) || cache.match('./');
      }),
    );
    return;
  }

  event.respondWith(
    caches.match(request).then(async (cached) => {
      if (cached) return cached;
      const response = await fetch(request);
      if (response.ok) {
        const cache = await caches.open(CACHE_NAME);
        await cache.put(request, response.clone());
      }
      return response;
    }),
  );
});
