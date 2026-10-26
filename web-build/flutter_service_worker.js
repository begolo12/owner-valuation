// Sisa service worker dari build Flutter web lama. Selama file ini masih
// terdaftar, browser menyajikan cache lama (index.html usang) → halaman putih.
// Worker ini hanya bertugas mencabut dirinya sendiri dan membuang semua cache.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.map((key) => caches.delete(key)));
      await self.registration.unregister();
      const clients = await self.clients.matchAll({ type: 'window' });
      clients.forEach((client) => client.navigate(client.url));
    })(),
  );
});
