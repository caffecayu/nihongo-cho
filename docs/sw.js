// Offline cache for the installed web app. Pages: network first, cached copy when offline.
// Voice files are left to the browser (Safari plays cached media unreliably through a service worker).
const C = "nihongo-cho-1.1.0";
const CORE = ["./", "index.html", "manifest.webmanifest", "icon-192.png",
  "vendor/kanjicanvas/kanji-canvas.js", "vendor/kanjicanvas/ref-patterns.js", "vendor/kanjicanvas/kana-strokes.json"];
self.addEventListener("install", e => { e.waitUntil(caches.open(C).then(c => c.addAll(CORE))); self.skipWaiting(); });
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener("fetch", e => {
  const u = new URL(e.request.url);
  if (e.request.method !== "GET" || u.origin !== location.origin || u.pathname.includes("/voice/")) return;
  const page = e.request.mode === "navigate" || u.pathname.endsWith("/") || u.pathname.endsWith("index.html");
  const save = r => { if (r.ok) { const cp = r.clone(); caches.open(C).then(c => c.put(e.request, cp)); } return r; };
  e.respondWith(page
    ? fetch(e.request).then(save).catch(() => caches.match(e.request).then(r => r || caches.match("index.html")))
    : caches.match(e.request).then(r => r || fetch(e.request).then(save)));
});
