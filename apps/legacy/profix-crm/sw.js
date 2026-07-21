// ProFix service worker — offline app shell. Bump CACHE to force update.
const CACHE = 'profix-v20';
const SHELL = ['/', '/index.html', 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL).catch(()=>{})).then(()=>self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;                       // let Supabase writes hit network
  const url = new URL(req.url);
  if (url.hostname.endsWith('supabase.co')) return;       // never cache API/auth
  e.respondWith(
    caches.match(req).then(cached =>
      cached || fetch(req).then(res => {
        const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); return res;
      }).catch(() => cached)
    )
  );
});
