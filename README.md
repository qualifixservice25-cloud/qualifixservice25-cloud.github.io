# Qualifix Service – sito unico delle app

Sito ufficiale di tutte le app Qualifix Service (GitHub Pages): https://qualifixservice25-cloud.github.io/

È l'unico repository pubblico dei siti: le app hanno il codice in repository privati, mentre qui stanno le pagine, le privacy policy e i file di verifica.

## Struttura

| Percorso | Cosa c'è |
|---|---|
| `index.html` | Pagina principale: le schede di tutte le app (italiano e inglese, `?lang=en`) |
| `calcolo-cartongesso/` | Sito e privacy di **Calcolo Cartongesso**, in 10 lingue (`?lang=de`) |
| `ottimizza-tagli/` | Sito e privacy di **Ottimizza Tagli** |
| `guida-filettature/` | Sito e privacy di **Guida Filettature** |
| `sviluppo-lamiera/` | Sito e privacy di **Sviluppo Lamiera** (in arrivo su Google Play) |
| `font/` | Inter e Inter Display, condivisi da hub, Ottimizza Tagli e Guida Filettature |
| `img/` | Icone delle app per la pagina principale |
| `privacy-policy.html` | Vecchio indirizzo della privacy di Calcolo Cartongesso: rimanda a quello nuovo. **Non cancellare.** |
| `app-ads.txt` | Verifica di Google AdMob, vale per tutte le app. **Non modificare.** |
| `.well-known/assetlinks.json` | Collegamento tra sito e app Calcolo Cartongesso. **Non modificare.** |
| `sitemap.xml`, `robots.txt` | Per Google Search Console |
| `.nojekyll` | Fa pubblicare anche la cartella `.well-known` |

### Aggiungere una nuova app

1. Crea la cartella `nome-app/` con `index.html` e `privacy-policy.html` (puoi partire da `guida-filettature/`).
2. Aggiungi la scheda in `index.html` (italiano e inglese in `TESTI`) e l'icona 192×192 in `img/`.
3. Aggiungi le due pagine a `sitemap.xml`.
4. In Play Console usa gli indirizzi qui sotto.

## Indirizzi da mettere in Play Console

Per **ogni** app: *Presenza nello store → Scheda principale dello store → Dettagli di contatto → Sito web* e *Norme relative alle app → Privacy policy*.

| App | Sito web | Privacy policy |
|---|---|---|
| Calcolo Cartongesso | `https://qualifixservice25-cloud.github.io/` | `https://qualifixservice25-cloud.github.io/calcolo-cartongesso/privacy-policy.html` |
| Ottimizza Tagli | `https://qualifixservice25-cloud.github.io/` | `https://qualifixservice25-cloud.github.io/ottimizza-tagli/privacy-policy.html` |
| Guida Filettature | `https://qualifixservice25-cloud.github.io/` | `https://qualifixservice25-cloud.github.io/guida-filettature/privacy-policy.html` |
| Sviluppo Lamiera | `https://qualifixservice25-cloud.github.io/` | `https://qualifixservice25-cloud.github.io/sviluppo-lamiera/privacy-policy.html` |

Il *Sito web* è la radice del dominio per tutte le app, ed è voluto: AdMob cerca `app-ads.txt` nella radice del dominio del sito dichiarato in Play.

## AdMob e app-ads.txt

`app-ads.txt` contiene una sola riga, quella del tuo account editore:

```
google.com, pub-4890369491929199, DIRECT, f08c47fec0942fa0
```

Quella riga vale per tutte le app dello stesso account AdMob, quindi non va toccata quando aggiungi un'app con pubblicità. Perché la verifica riesca:

1. In Play Console, il *Sito web* dell'app deve essere `https://qualifixservice25-cloud.github.io/` (oppure una pagina di questo dominio).
2. L'app deve essere collegata allo store in AdMob (*App → Impostazioni app → Store dell'app*).
3. In AdMob → *App → app-ads.txt* attendi la scansione (fino a 24 ore dopo la modifica in Play) oppure usa *Verifica aggiornamenti*.
4. Controllo rapido: https://qualifixservice25-cloud.github.io/app-ads.txt deve aprirsi e mostrare la riga sopra.

Se un giorno aggiungi un'altra rete pubblicitaria (mediazione), le sue righe si aggiungono **sotto** quella di Google, senza togliere niente.

## Pubblicazione

GitHub Pages: *Settings → Pages* → Source: branch `main`, cartella `/ (root)`. Per aggiornare il sito si unisce in `main` il branch con le modifiche.

I vecchi indirizzi continuano a funzionare grazie alle pagine di rimando nei repository `site-ottimizza_tagli` (`/site-ottimizza_tagli/`) e `Sites` (`/Sites/`). Tienile pubblicate per qualche mese dopo aver cambiato gli indirizzi in Play Console.

## Lingue di Calcolo Cartongesso

Nel sito di Calcolo Cartongesso la lingua si sceglie dal menu in alto; all'apertura parte quella del browser (se non è tra le 10, l'inglese). Si può linkare una lingua con `?lang=de`. I testi sono nell'oggetto `TESTI` in fondo a ogni pagina, una voce per lingua con le stesse chiavi. Gli screenshot vengono da `docs/screenshot_store/` del repository dell'app, convertiti in WebP 540 × 1080 dentro `calcolo-cartongesso/img/`.

---
*Gestito da Qualifix Service - 2026*
