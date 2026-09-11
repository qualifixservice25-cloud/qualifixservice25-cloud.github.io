# Piano di progetto — Sviluppo Lamiera (Flutter: web e Android)

Nome dell'app: Sviluppo Lamiera · Package: `org.qualifix.service.sviluppolamiera`

Versione web: sito Netlify dedicato, compilato e pubblicato dalla GitHub Action. I passi
per collegarlo sono nel [README della radice](../README.md#da-fare-una-volta-sola-collegare-netlify).

## 1. Obiettivo e ambito

App per chi sta davanti a una pressa piegatrice e deve sapere **quanto sviluppare la
lamiera prima di tagliarla**. Oggi quel calcolo si fa a memoria, con tabelle fotocopiate o
con la "cala" a occhio («due volte lo spessore»). Finché si piega acciaio dolce da 2 mm a
90° la regola empirica regge; con l'inox, con gli spessori grossi, con i raggi larghi o con
angoli diversi da 90° non regge più, e il pezzo esce sbagliato. Un errore di sviluppo non
si recupera: la lamiera è già tagliata.

Il valore dell'app non è il numero finale, è **rendere visibile la catena** che lo produce:

> cava scelta → raggio interno che si forma davvero in aria → fattore K → sviluppo

Fuori ambito per la v1: tonnellaggio, ritorno elastico, battute posteriori, scheda PDF,
disegno libero delle sagome utensile, qualunque calcolo in tre dimensioni.

## 2. Nomenclatura e formule

| Simbolo | Significato |
|---|---|
| `S` | spessore della lamiera, mm |
| `Ri` | raggio interno di piega, mm |
| `V` | apertura della cava, mm |
| `α` | angolo formato, quello che si legge sul pezzo col goniometro |
| `β` | angolo di rotazione, `180 − α` |
| `K` | fattore K: distanza dell'asse neutro dalla faccia interna, in frazioni di `S` |

```
BA   = (π/180) · β · (Ri + K·S)      abbuono, lo sviluppo dell'arco
OSSB = tan(β/2) · (Ri + S)           sporgenza esterna
BD   = 2·OSSB − BA                   detrazione, la "cala"

Sviluppo da quote esterne:  L = Σ lati esterni − Σ BD
Sviluppo da tratti piani:   L = Σ tratti piani + Σ BA
```

**Fattore K secondo DIN 6935:** `k = 0,65 + 0,5 · log10(Ri/S)`, limitato a `[0, 1]`, e
`K = k/2`. La formula riproduce quasi esattamente la regola di officina «oltre cinque
spessori di raggio l'asse neutro sta in mezzo»: a `Ri/S = 5` dà `K = 0,49974`, e tocca il
massimo `0,5` a `Ri/S = 5,012`. Mezzo millesimo di spessore — ininfluente al banco, ma
scritto invece che arrotondato via.

**La catena della piega in aria.** In piega in aria il raggio interno non si sceglie: lo
produce la cava, `Ri = c · V`.

| Materiale | `c` |
|---|---|
| Acciaio dolce, zincato | 0,158 |
| Acciaio S355 | 0,162 |
| Inox AISI 304 | 0,175 |
| Inox AISI 430 | 0,170 |
| Alluminio 5754 | 0,145 |
| Alluminio 6082 | 0,150 |
| Rame | 0,140 |
| Ottone | 0,145 |

**Scelta della cava:** `V = 8·S` fino a 3 mm, `10·S` fino a 8, `12·S` fino a 10, `14·S`
oltre. **Lato minimo:** `b_min = 0,65 · V` a 90°, con il coefficiente calibrabile dalle
impostazioni.

## 3. Architettura tecnica

Due pacchetti Dart distinti, e la separazione è **strutturale, non di convenzione**:

- `sviluppo-lamiera-app/core/` — Dart puro. Il suo `pubspec.yaml` non ha `flutter` fra le
  dipendenze, quindi importare `package:flutter/…` lì dentro semplicemente non compila. I
  test girano con il solo SDK Dart: niente SDK Android, niente emulatore. È la stessa
  proprietà del modulo `:core` del CAD Viewer, qui garantita dal gestore di pacchetti
  invece che dalla buona volontà.
- `sviluppo-lamiera-app/app/` — l'interfaccia Flutter, che dipende dal core per percorso.

Dentro il core: `geometria/` (vettori, poligoni, intersezioni), `materiali/`, `utensili/`
(modelli, sagome parametriche, catalogo, scelta della cava), `piega/` (fattore K, calcolo,
taratura), `profilo/` (modello del pezzo e sua geometria formata), `sviluppo/`,
`sequenza/` (lato minimo, posizionamento sulla cava, collisioni, motore di ricerca),
`archivio/` (serializzazione e impostazioni), `formato/`.

**Stato dell'interfaccia:** `ChangeNotifier` e `InheritedNotifier`, quelli di Flutter.
Nessuna libreria di state management: cinque schermate che leggono lo stesso documento non
giustificano una dipendenza in più né il modello mentale che si porta dietro.

**Persistenza:** `shared_preferences`, unico plugin del progetto. Stessa API su Android e
su web, nessun codice condizionale, nessun asset da servire. Ogni chiave è un documento
JSON con un numero di versione dal primo giorno.

## 4. Motore di sequenza e collisioni

La parte più difficile, e quella dove è più facile promettere troppo.

**Posizionamento.** Il passaggio che di solito viene approssimato male: la lamiera non
resta appoggiata sul piano della cava, ci scende dentro mentre si piega. La superficie
esterna è un arco di raggio `Ro` tangente alle due rette di appoggio che passano per le
spalle, quindi per simmetria il centro sta sull'asse verticale a

```
yc = (Ro − (V/2)·sin φ) / cos φ        con φ = (180 − θ)/2
```

Con `θ = 180°` la formula restituisce `Ro`, cioè lamiera piatta appoggiata sulle spalle:
copre anche l'istante iniziale senza casi particolari. Con V16 a 90° su 2 mm di acciaio il
pezzo scende 6,12 mm dentro una cava profonda 8,73: non tocca il fondo, ed è il valore
giusto di officina.

**Ricerca.** Non sulle permutazioni ma **sui sottoinsiemi**: la fattibilità di una piega
dipende da *quali* pieghe sono già state fatte, non dall'ordine in cui sono state fatte.
Lo spazio scende da `n!` a `n·2ⁿ` stati, tutti memoizzati, e una ricerca a fascio li
percorre tenendo le combinazioni più promettenti. Quando il fascio deve potare, l'app lo
**dichiara** invece di far finta di aver guardato tutto.

**Due misure diverse per due contatti diversi.** Contro il coltello si misura la distanza:
fuori dalla zona di formatura, qualunque contatto è un urto. Contro la cava si misura la
compenetrazione: la lamiera ci appoggia sopra per tutta la sua lunghezza, e chiamare
collisione quell'appoggio renderebbe impossibile qualunque piega.

**Cosa rileva:** interferenza lembo-coltello nella sezione (collo d'oca compreso, che è
solo un poligono concavo e non un caso speciale), pezzo dentro il corpo della cava o contro
il banco, lembi sotto il minimo piegabile, pezzo più alto dell'utensile, e le interferenze
che nascono a metà corsa invece che a fondo corsa — la corsa viene campionata.

**Cosa non rileva** — ed è scritto dentro l'app, non solo qui: tutto ciò che è in tre
dimensioni (angoli di scatola, pareti laterali, pieghe non parallele), telaio e
portautensili, ditali della battuta e assi R/Z, peso del pezzo e mano dell'operatore,
ritorno elastico. Le sequenze si chiamano **proposte**, mai *verificate*.

## 5. Interfaccia

Cinque schede, pensate per un tablet appoggiato alla macchina: bersagli da 56 dp, campi
numerici grandi, virgola decimale, unità sempre esplicite, **modalità officina** scura ad
alto contrasto (la stessa scelta della "modalità cantiere" del CAD Viewer).

| Scheda | Contenuto |
|---|---|
| Piega | Il calcolatore della singola piega, con la catena di derivazione riga per riga |
| Sviluppo | Editor del pezzo, disegno della sezione, lamiera distesa con le linee di piega quotate, tabella per piega |
| Sequenza | Ordine proposto, navigazione passo per passo, disegno di cava + coltello + pezzo, elenco dei limiti del controllo |
| Utensili | Inventario personale di coltelli e cave, con anteprima della sagoma mentre si digitano le misure |
| Impostazioni | Taratura da provino, coefficiente del lato minimo, giochi, decimali, tema, ripristino catalogo |

## 6. Stack tecnologico

Flutter · Dart puro per il motore · `CustomPainter` per tutti i disegni · `ChangeNotifier`
per lo stato · `shared_preferences` per la persistenza · Roboto impacchettato.

**Una sola dipendenza di terze parti in tutto il progetto.** Scartate con motivo: `intl`
(una lingua sola; la formattazione italiana sono quindici righe), `vector_math` (il core
deve restare senza dipendenze), `provider`/`riverpod`/`bloc` (stato banale), `sqflite`/
`hive`/`isar` (non funzionano su web senza asset e worker aggiuntivi), `cupertino_icons`
(inutilizzata, rimossa da quella che genera `flutter create`).

## 7. Roadmap e stato

| Fase | Contenuto | Stato |
|---|---|---|
| 0 | Validazione della catena sui casi noti | Fatta |
| 1 | Core: materiali, utensili, fattore K, sviluppo, taratura | Fatta |
| 2 | Lato minimo, posizionamento, collisioni, motore di sequenza | Fatta |
| 3 | Le cinque schermate, disegni, modalità officina | Fatta |
| 4 | Inventario personale: CRUD, persistenza, catalogo di partenza | Fatta |
| 5 | Build web, PWA offline, CI con test bloccanti, pubblicazione su Netlify | Fatta |
| 6 | Tonnellaggio e verifica del carico di pressa e utensile | Da fare |
| 7 | Ritorno elastico e raggio minimo di piega | Da fare |
| 8 | Battute posteriori e quote a CN | Da fare |
| 9 | Scheda di lavorazione in PDF | Da fare |
| 10 | Compilazione APK, landing page, pubblicazione Play Store | Da fare |

**108 test automatici** (102 sul core in Dart puro, 6 d'insieme sull'interfaccia).

## 8. Rischi principali

- **«Numeri plausibili ma sbagliati».** Il rischio più grave del progetto, come per il CAD
  Viewer, ma qui peggiore: uno sviluppo sbagliato non produce una quota brutta, manda a
  scarto della lamiera, e lo fa in silenzio perché 194 e 196 sono ugualmente credibili. Le
  contromisure stanno tutte in v1 e sono elencate sotto.
- **Il motore di sequenza che dà falsa sicurezza.** Mitigato chiamandole proposte e
  mettendo l'elenco di cosa non viene controllato dentro l'app.
- **Peso della build web.** Circa 17 MB, di cui 12 sono i due `canvaskit.wasm` necessari a
  coprire Chromium e gli altri browser. Non stanno nel repository — li genera la CI a ogni
  pubblicazione — e Netlify li serve compressi, quindi chi apre l'app ne scarica circa
  cinque; dal secondo avvio è il service worker a rispondere.
- **La pubblicazione dipende da due segreti** (`NETLIFY_AUTH_TOKEN` e `NETLIFY_SITE_ID`).
  Se mancano o scadono, la Action si ferma con un messaggio esplicito invece di fallire in
  modo oscuro.
- **Inventario digitato a mano.** Un'apertura V sbagliata sbaglia tutto a valle in
  silenzio: da qui la validazione dei campi e il nome della cava sempre accanto al
  risultato.
- **Percorso Android non ancora compilato.** La cartella `android/` è configurata col
  package giusto ma non è mai passata da un SDK Android.

## 9. Come si difende l'utente dai numeri sbagliati

1. **Nessun risultato nudo.** Ogni numero porta con sé la derivazione:
   `V = 16 → Ri = 0,158 · 16 = 2,53 → Ri/S = 1,26 → k = 0,701 → K = 0,350 → BA = 5,07 ·
   OSSB = 4,53 · BD = 3,98`. Un piegatore esperto becca un raggio sbagliato in un secondo;
   un numero nudo non può controllarlo.
2. **L'origine di ogni valore è etichettata**: calcolato dalla cava, impostato a mano,
   tarato su prova.
3. **Il controllo di buon senso in chiaro**: accanto alla detrazione compare «≈ 1,99 × lo
   spessore», che è la regola che ogni piegatore ha in testa.
4. **Mai indovinare in silenzio.** Senza una cava adatta il calcolo si ferma e lo dice,
   invece di ripiegare di nascosto su un valore teorico.
5. **Taratura da provino.** L'utente piega un pezzo di prova, misura lo sviluppo reale, e
   l'app risolve a ritroso il fattore K della *sua* macchina con *quel* materiale. È il
   passaggio da «fidati della formula» a «fidati del tuo acciaio».
6. **Una riga fissa sulla scheda Sviluppo**, noiosa e probabilmente la più utile dell'app:
   *«Verifica sempre su un ritaglio prima di tagliare la serie.»*

E nei test: i casi di riferimento verbatim, l'identità algebrica fra quote esterne e tratti
piani, l'assenza di NaN su tutto il dominio, e soprattutto **l'invarianza di scala** — con
`V = 8·S` il rapporto `Ri/S` è costante, quindi `BD/S` deve valere 1,992 per *qualunque*
spessore. Qualsiasi costante assoluta infilata per sbaglio nelle formule la rompe.

## 10. Prossimi passi

1. Compilare l'APK su una macchina con Android Studio e provarlo su un tablet vero.
2. Tarare i coefficienti su pieghe reali, almeno per acciaio dolce e inox.
3. Tonnellaggio (Fase 6), che è una formula sola e usa la `Rm` già in tabella.
4. Ritorno elastico (Fase 7): senza, l'angolo mostrato è quello a fondo corsa, e l'app lo
   dichiara.
