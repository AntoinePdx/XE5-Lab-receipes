const CACHE_NAME = 'fuji-recipes-v1';
const PRECACHE = [
  '/',
  '/index.html'
];
self.addEventListener('install', (ev) => {
  ev.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE))
  );
  self.skipWaiting();
});
self.addEventListener('activate', (ev) => {
  ev.waitUntil(self.clients.claim());
});
self.addEventListener('fetch', (ev) => {
  if (ev.request.method !== 'GET') return;
  ev.respondWith(
    caches.match(ev.request).then((r) => r || fetch(ev.request).then((res) => {
      if (!res || res.status !== 200 || res.type !== 'basic') return res;
      const copy = res.clone();
      caches.open(CACHE_NAME).then((cache) => cache.put(ev.request, copy));
      return res;
    })).catch(() => caches.match('/index.html'))
  );
});
