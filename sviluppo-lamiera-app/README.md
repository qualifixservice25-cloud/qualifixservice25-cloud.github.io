# Sviluppo Lamiera

Calcolo della piegatura per chi lavora alla pressa piegatrice: fattore K secondo DIN 6935,
sviluppo della lamiera, lato minimo piegabile e sequenza delle pieghe con verifica delle
collisioni, sul proprio parco di cave e coltelli.

Un solo codice Flutter per **web** e **Android**.

Piano di progetto completo: [`docs/piano-progetto-sviluppo-lamiera.md`](../docs/piano-progetto-sviluppo-lamiera.md)

## Struttura

```
core/    motore di calcolo — Dart PURO, nessuna dipendenza da Flutter
app/     interfaccia Flutter (web + Android)
scripts/ build-web.sh: compila e pubblica in ../sviluppo-lamiera/
```

I due pacchetti sono separati apposta. Il `pubspec.yaml` di `core/` non elenca `flutter`
fra le dipendenze, quindi importare `package:flutter/…` lì dentro **non compila**: la
garanzia che il motore resti testabile senza SDK Android è strutturale, non affidata alla
buona volontà di chi scrive. È la stessa proprietà del modulo `:core` di
[`android-cad-viewer/`](../android-cad-viewer/README.md), qui imposta dal gestore di
pacchetti.

## Compilare e provare

Serve solo l'SDK Flutter ([installazione](https://docs.flutter.dev/get-started/install)).

```bash
# Il motore di calcolo, senza Flutter e senza SDK Android: bastano 5 secondi
cd core && dart pub get && dart analyze && dart test

# L'interfaccia
cd ../app && flutter pub get && flutter analyze && flutter test

# La versione web, pubblicata in ../../sviluppo-lamiera/
../scripts/build-web.sh
```

**108 test**: 102 sul core (casi di riferimento, invarianti, geometria, robustezza,
sequenza, persistenza) e 6 d'insieme sull'interfaccia vera con un archivio in memoria.

### APK Android

```bash
cd app && flutter build apk --debug
```

Richiede l'SDK Android con `ANDROID_HOME` impostato. **Questo percorso non è mai stato
compilato**: la cartella `android/` è configurata col package
`org.qualifix.service.sviluppolamiera` e l'etichetta giusta, ma va provata su una macchina
con Android Studio prima di fidarsi.

## Scelte tecniche

**Una sola dipendenza di terze parti in tutto il progetto**, `shared_preferences`, perché
è l'unica cosa che non si può fare in Dart puro: la persistenza locale. Ha la stessa API su
Android e su web, non richiede codice condizionale né asset aggiuntivi. Tutto il resto —
disegni con `CustomPainter`, stato con `ChangeNotifier`, JSON con `dart:convert`,
formattazione italiana scritta a mano — sta già nell'SDK.

**Roboto è impacchettato nell'app** invece di essere scaricato da Google al primo avvio, e
**CanvasKit è servito in locale** invece che da `gstatic.com`. Senza queste due scelte
l'app non partirebbe in un'officina senza rete o dietro un firewall — che è esattamente
dove deve funzionare. Per lo stesso motivo nelle stringhe si scrive `log10` e non `log₁₀`:
i pedici Unicode non stanno in Roboto e costringerebbero a scaricare un font di ripiego.

**Il renderer è fissato su CanvasKit** in `app/web/flutter_bootstrap.js`. È quello che gira
ovunque, e senza il vincolo la build dovrebbe portarsi dietro ogni variante di renderer:
41 MB invece di 17.

**Il service worker è scritto a mano** (`app/web/sw.js`). Dalla versione 3.29 Flutter non
genera più un service worker che mette in cache l'app: quello che produce oggi è solo uno
stub che si disiscrive da solo per ripulire le installazioni vecchie. Senza `sw.js` l'app
avrebbe la sola cache HTTP del browser e in officina senza rete non si aprirebbe. La
strategia è cache-first con riempimento durante l'uso, così non c'è nessun elenco di file
da tenere allineato a ogni rilascio; `build-web.sh` marchia il nome della cache con la data
della build perché una versione nuova sostituisca la precedente.

Provato davvero: staccando la rete dopo il primo avvio, l'app riparte in circa 2 secondi
con i calcoli a schermo.

## Limiti noti

- **Il controllo delle collisioni guarda solo la sezione.** Non vede gli angoli di scatola,
  le pareti laterali, le pieghe non parallele, il telaio, i portautensili, i ditali della
  battuta, il peso del pezzo. Le sequenze sono **proposte**, non verifiche, e l'app lo
  scrive dentro invece di nasconderlo nella documentazione.
- **Nessun ritorno elastico.** Gli angoli sono quelli a fondo corsa, non quelli del pezzo
  una volta rilasciato.
- **Niente tonnellaggio e niente battute.** Sono pianificati (Fase 6 e 8).
- **I coefficienti sono valori tipici**, non i numeri della tua macchina. Per quelli c'è la
  taratura da provino in Impostazioni: pieghi un pezzo di prova, misuri lo sviluppo reale,
  e l'app ricava a ritroso il fattore K effettivo.
- **Sul web l'inventario vive nel `localStorage` del browser**: se si cancellano i dati del
  sito, sparisce. L'app lo avvisa in Impostazioni.

## Pubblicazione web

`scripts/build-web.sh` compila, toglie quello che il browser non scarica mai (i `.symbols`
e le varianti di renderer inutilizzate) e copia il risultato in `sviluppo-lamiera/` alla
radice del repository, da dove GitHub Pages lo serve su
<https://qualifixservice25-cloud.github.io/sviluppo-lamiera/>.

La build pesa circa 17 MB ed è **committata**: va quindi rigenerata solo sui commit di
rilascio, mai a ogni modifica di codice, altrimenti la storia del repository si gonfia
senza motivo.
