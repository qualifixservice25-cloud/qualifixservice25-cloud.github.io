'use strict';

// Service worker di Sviluppo Lamiera.
//
// Perché scritto a mano invece di usare quello di Flutter: dalla versione 3.29
// Flutter non genera più un service worker che mette in cache l'app. Quello che
// produce oggi (`flutter_service_worker.js`) è solo uno stub che si disiscrive
// da solo, per ripulire le installazioni vecchie. Senza questo file l'app
// avrebbe solo la cache HTTP del browser, e in un'officina senza rete non si
// aprirebbe — che è esattamente il caso per cui esiste.
//
// Strategia: cache-first con riempimento durante l'uso. Al primo avvio con
// rete ogni file che il browser scarica finisce in cache; dagli avvii
// successivi l'app parte anche senza rete. Non c'è nessun elenco di file da
// tenere aggiornato a mano — un elenco sbagliato è il modo più comune di
// rompere un service worker a ogni rilascio.

const VERSIONE = 'sviluppo-lamiera-BUILD_ID';

// Il minimo per far comparire qualcosa: il resto si accumula durante l'uso.
const ESSENZIALI = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'manifest.json',
];

self.addEventListener('install', (evento) => {
  evento.waitUntil(
    caches
      .open(VERSIONE)
      .then((cache) => cache.addAll(ESSENZIALI))
      .then(() => self.skipWaiting())
      // Se un essenziale non si scarica non si blocca l'installazione: meglio
      // un service worker che parte a metà di nessun service worker.
      .catch(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (evento) => {
  evento.waitUntil(
    caches
      .keys()
      .then((nomi) =>
        Promise.all(
          nomi
            .filter((n) => n.startsWith('sviluppo-lamiera-') && n !== VERSIONE)
            .map((n) => caches.delete(n)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (evento) => {
  const richiesta = evento.request;

  // Solo GET e solo la nostra origine: le richieste altrui non si toccano.
  if (richiesta.method !== 'GET') return;
  const url = new URL(richiesta.url);
  if (url.origin !== self.location.origin) return;

  // La navigazione va sempre servita dall'index dell'app: così l'indirizzo
  // funziona anche ricaricando a freddo senza rete.
  if (richiesta.mode === 'navigate') {
    evento.respondWith(
      fetch(richiesta).catch(() =>
        caches.match('index.html', { cacheName: VERSIONE }).then(
          (r) => r || caches.match('./', { cacheName: VERSIONE }),
        ),
      ),
    );
    return;
  }

  evento.respondWith(
    caches.match(richiesta).then((inCache) => {
      if (inCache) return inCache;
      return fetch(richiesta)
        .then((risposta) => {
          // Si mette da parte solo quello che è arrivato davvero intero.
          if (risposta && risposta.status === 200 && risposta.type === 'basic') {
            const copia = risposta.clone();
            caches.open(VERSIONE).then((cache) => cache.put(richiesta, copia));
          }
          return risposta;
        })
        .catch(() => inCache);
    }),
  );
});

// Permette alla pagina di forzare l'attivazione di una versione nuova.
self.addEventListener('message', (evento) => {
  if (evento.data === 'aggiorna') self.skipWaiting();
});
