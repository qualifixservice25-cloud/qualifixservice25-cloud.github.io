# Qualifix Service

Repository ufficiale del sito, delle landing page e dei file di configurazione delle app
**Qualifix Service**.

## Le app

### Sviluppo Lamiera — web app

Calcolo della piegatura per chi lavora alla pressa piegatrice: fattore K secondo DIN 6935,
sviluppo della lamiera, lato minimo piegabile e sequenza delle pieghe, sul proprio parco di
cave e coltelli. Funziona nel browser e, dopo il primo avvio, anche senza rete.

- Aprila: <https://qualifixservice25-cloud.github.io/sviluppo-lamiera/>
- Sorgenti: [`sviluppo-lamiera-app/`](sviluppo-lamiera-app/README.md)
- Piano di progetto: [`docs/piano-progetto-sviluppo-lamiera.md`](docs/piano-progetto-sviluppo-lamiera.md)

### Calcolo Cartongesso — Android

Conteggio di lastre, profili, viti e stucco per chi lavora in cantiere.

- [Scaricala su Google Play](https://play.google.com/store/apps/details?id=org.qualifix.service.calcolocartongesso)

## Contenuti del repository

| Percorso | Cosa contiene |
|---|---|
| `index.html` | Home del sito |
| `privacy-policy.html` | Informativa sulla privacy richiesta da Google Play |
| `sviluppo-lamiera/` | Build web pubblicata di Sviluppo Lamiera — **generata**, non modificare a mano |
| `sviluppo-lamiera-app/` | Sorgenti di Sviluppo Lamiera (Flutter: core Dart puro + app) |
| `docs/` | Piani di progetto |
| `app-ads.txt` | Verifica per Google AdMob (standard IAB Tech Lab) |
| `.well-known/assetlinks.json` | Android App Links |
| `.nojekyll` | Disattiva Jekyll, così i file tecnici vengono serviti tali e quali |

> **Attenzione ai due nomi che si somigliano:** `sviluppo-lamiera/` è la build pubblicata e
> va committata, perché è quella che GitHub Pages serve. `sviluppo-lamiera-app/app/build/`
> è la cartella di lavoro del compilatore ed è ignorata da git. Per rigenerare la prima si
> lancia `sviluppo-lamiera-app/scripts/build-web.sh`, e solo sui commit di rilascio.

## Link utili

- [Sito ufficiale](https://qualifixservice25-cloud.github.io/)
- Contatti: <qualifix.service25@gmail.com>

---
*Gestito da Qualifix Service - 2026*
