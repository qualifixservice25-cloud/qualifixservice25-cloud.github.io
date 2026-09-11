# Qualifix Service

Repository ufficiale del sito, delle landing page e dei file di configurazione delle app
**Qualifix Service**.

## Le app

### Sviluppo Lamiera — web app

Calcolo della piegatura per chi lavora alla pressa piegatrice: fattore K secondo DIN 6935,
sviluppo della lamiera, lato minimo piegabile e sequenza delle pieghe, sul proprio parco di
cave e coltelli. Funziona nel browser e, dopo il primo avvio, anche senza rete.

- Sorgenti: [`sviluppo-lamiera-app/`](sviluppo-lamiera-app/README.md)
- Piano di progetto: [`docs/piano-progetto-sviluppo-lamiera.md`](docs/piano-progetto-sviluppo-lamiera.md)
- Pubblicata su un sito Netlify dedicato — vedi «Da fare una volta sola» qui sotto

### Calcolo Cartongesso — Android

Conteggio di lastre, profili, viti e stucco per chi lavora in cantiere.

- [Scaricala su Google Play](https://play.google.com/store/apps/details?id=org.qualifix.service.calcolocartongesso)

## Da fare una volta sola: collegare Netlify

Sviluppo Lamiera non è ancora online. La compilazione e la pubblicazione le fa da sé la
GitHub Action in [`.github/workflows/sviluppo-lamiera.yml`](.github/workflows/sviluppo-lamiera.yml),
ma prima servono tre passi:

1. **Crea il sito su Netlify.** Nuovo sito, collegato a questo repository. Non impostare
   nessun comando di build: ci pensa la Action, e Netlify si limita a servire quello che
   riceve (le impostazioni stanno in [`netlify.toml`](netlify.toml)).
2. **Copia i due segreti su GitHub**, in *Settings → Secrets and variables → Actions →
   New repository secret*:
   - `NETLIFY_SITE_ID` — su Netlify: *Site configuration → General → Site ID*
   - `NETLIFY_AUTH_TOKEN` — su Netlify: *User settings → Applications → New access token*
3. **Sostituisci l'indirizzo in `index.html`.** C'è un solo segnaposto,
   `INDIRIZZO-NETLIFY-DA-SOSTITUIRE`, con accanto un commento che lo spiega.

Da quel momento ogni push su `main` che tocchi l'app compila, esegue i 108 test e — solo
se passano tutti — pubblica. Se un test fallisce, la pubblicazione non parte: è il motivo
per cui la CI esiste, perché qui uno sviluppo sbagliato manda a scarto lamiera vera.

## Contenuti del repository

| Percorso | Cosa contiene |
|---|---|
| `index.html` | Home del sito |
| `privacy-policy.html` | Informativa sulla privacy richiesta da Google Play |
| `sviluppo-lamiera-app/` | Sorgenti di Sviluppo Lamiera (Flutter: core Dart puro + app) |
| `.github/workflows/` | CI: test bloccanti e pubblicazione su Netlify |
| `netlify.toml` | Come Netlify serve l'app: cache, intestazioni, rotte |
| `docs/` | Piani di progetto |
| `app-ads.txt` | Verifica per Google AdMob (standard IAB Tech Lab) |
| `.well-known/assetlinks.json` | Android App Links |
| `.nojekyll` | Disattiva Jekyll |

La build web **non è versionata**: la genera la CI a ogni pubblicazione. Chi compila in
locale se la ritrova in `sviluppo-lamiera-app/app/build/web`, che è ignorata da git.

## Link utili

- [Sito ufficiale](https://qualifixservice25-cloud.github.io/)
- Contatti: <qualifix.service25@gmail.com>

---
*Gestito da Qualifix Service - 2026*
