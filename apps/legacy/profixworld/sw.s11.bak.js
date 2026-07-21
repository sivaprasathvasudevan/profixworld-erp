/* ProFix store service worker — app-shell cache, network-first navigation.
   Supabase (cross-origin) is always network, never cached. */
const CACHE = 'profix-store-v8';
const SHELL = ['/', '/index.html', '/manifest.webmanifest', '/icon-192.png', '/icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(SHELL)).catch(() => {}).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Only handle same-origin. Supabase / fonts / CDNs go straight to network.
  if (url.origin !== self.location.origin) return;

  // Navigations: network-first, fall back to cached shell when offline.
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req)
        .then(r => { const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); return r; })
        .catch(() => caches.match(req).then(m => m || caches.match('/')))
    );
    return;
  }

  // Static assets: cache-first, then network (and cache it).
  e.respondWith(
    caches.match(req).then(m => m || fetch(req).then(r => {
      const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); return r;
    }).catch(() => m))
  );
});

// ---- Web Push: show notification + focus/open the app on tap ----
self.addEventListener('push', e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { title: 'ProFix', body: e.data ? e.data.text() : '' }; }
  const title = d.title || 'ProFix';
  const opts = {
    body: d.body || '',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    data: { url: d.url || '/' },
    vibrate: [120, 60, 120],
    tag: d.tag || undefined,
    renotify: !!d.tag
  };
  e.waitUntil(self.registration.showNotification(title, opts));
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || '/';
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(cs => {
      for (const c of cs) { if (c.url.includes(url) && 'focus' in c) return c.focus(); }
      for (const c of cs) { if ('focus' in c) { c.navigate && c.navigate(url); return c.focus(); } }
      return self.clients.openWindow(url);
    })
  );
});
