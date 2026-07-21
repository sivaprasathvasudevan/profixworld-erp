// ProFix Driver PWA service worker - network-first, minimal cache
const C = "pfx-driver-v1";
self.addEventListener("install", e => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(clients.claim()));
self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return;
  e.respondWith(
    fetch(e.request).then(r => {
      const cp = r.clone();
      caches.open(C).then(c => c.put(e.request, cp)).catch(()=>{});
      return r;
    }).catch(() => caches.match(e.request))
  );
});
