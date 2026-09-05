# Qualifix CAD — visualizzatore DXF con quotatura

App Android per aprire disegni CAD in cantiere e quotarli sul posto: quote lineari, allineate,
angolari, radiali, diametrali e ordinate, con aggancio ai punti notevoli del disegno.

Piano di progetto completo: [`docs/piano-progetto-cad-viewer.md`](../docs/piano-progetto-cad-viewer.md).

## Struttura

| Modulo | Cosa contiene | Dipende da Android |
|---|---|---|
| `core` | Parser DXF, geometria, snap engine, motore di quotatura, export DXF, client di conversione DWG | No, Kotlin puro |
| `app` | Rendering su Canvas, gesti, interfaccia Compose, apertura file, export PDF | Sì |
| `server` | Server Python self-hosted che converte DWG in DXF (wrapper attorno a ODA File Converter) | No, non e' Kotlin |

La separazione non è formale: tutto ciò che decide **quanto misura una quota** sta in `core` ed è
coperto da test che girano su una JVM qualunque. In `app` resta solo ciò che è davvero legato al
telefono — pixel, dita e file.

```
core/src/main/kotlin/org/qualifix/cad/core/
├── geometry/    Vec2, Bounds, archi da bulge, trasformazioni affini
├── model/       entità CAD, layer, blocchi, unità di disegno, tavolozza ACI
├── dxf/         lettura e scrittura DXF ASCII
├── snap/        aggancio a fine/intersezione/medio/centro/quadrante/perpendicolare
├── measure/     conversione fra unità, formattazione, tolleranze
├── dimension/   quote, stili, geometria disegnata, serie concatenate e da linea base
├── dwg/         client verso il server di conversione DWG (protocollo in server/README.md)
└── tool/        macchina a stati degli strumenti di quotatura
```

## Scaricare il progetto

```bash
git clone https://github.com/qualifixservice25-cloud/qualifixservice25-cloud.github.io.git
cd qualifixservice25-cloud.github.io
git checkout claude/android-dwg-dxf-viewer-nb6plw
cd android-cad-viewer
```

## Compilare e testare

Nel progetto c'è il **Gradle wrapper**: non serve installare Gradle, `./gradlew` scarica da solo la
versione giusta al primo avvio (su Windows si usa `gradlew.bat`).

Il core si compila e si testa **senza SDK Android**, basta una JDK 17 o superiore:

```bash
./gradlew :core:test       # 84 test unitari
```

Il server di conversione DWG (`server/`) e' Python, non Gradle, e si testa a parte — solo
libreria standard, nessuna dipendenza da installare:

```bash
cd server && python3 -m unittest discover -s tests -v      # 22 test
```

Se l'SDK Android non è installato, `settings.gradle.kts` esclude automaticamente il modulo `:app`,
così i test del core restano eseguibili anche in CI. Con Android Studio (o con `ANDROID_HOME`
impostato) il modulo `:app` viene incluso e si compila normalmente:

```bash
./gradlew :app:assembleDebug     # APK in app/build/outputs/apk/debug/
./gradlew :app:installDebug      # installa sul telefono collegato via USB
```

### Con quale editor

L'app va aperta in **Android Studio**: `File → Open` sulla cartella `android-cad-viewer` (non sulla
radice del repository), poi si aspetta la sincronizzazione Gradle. Android Studio porta con sé
l'SDK, l'emulatore e il debugger — VS Code no.

VS Code va bene per leggere e modificare il **core**: serve la JDK e l'estensione *Kotlin*, e i test
si lanciano dal terminale integrato con il comando qui sopra. Per costruire l'APK serve comunque
l'SDK Android.

## Scelte tecniche

**Le unità di misura sono il punto critico.** L'app legge `$INSUNITS` dall'header del DXF e, se il
disegno non dichiara l'unità, **non converte niente**: mostra il valore grezzo e lo dice nella barra
di stato. Una conversione inventata produrrebbe numeri plausibili e sbagliati, che è il modo
peggiore di sbagliare per uno strumento da cantiere.

**Il file aperto non viene mai modificato.** Le quote vivono accanto al documento e finiscono nel
disegno solo all'esportazione, su un layer dedicato (`QUOTE_APP`).

**L'export DXF è in formato R12.** È il formato più vecchio e quindi quello che qualunque CAD
riapre senza discussioni. Le quote vengono scritte come geometria (linee, frecce piene, testo) su
un layer separato invece che come entità `DIMENSION` associative: una DIMENSION R12 richiede il
blocco anonimo che la disegna, e un blocco scritto male è peggio di nessun blocco.

**Il parser non fallisce sulle entità che non conosce.** Un disegno reale contiene sempre qualcosa
di proprietario: quelle entità finiscono negli avvisi del documento e il resto si apre lo stesso.

**Interazione a una mano.** Senza strumento attivo un dito trascina il disegno. Con uno strumento di
quotatura attivo, un dito posiziona il mirino e mostra l'aggancio *prima* di confermare, sollevando
il dito; due dita fanno sempre zoom e spostamento.

**Il DWG passa da un server, non da una libreria sul telefono.** Le librerie che leggono DWG
nativamente (ODA Drawings SDK, Aspose.CAD) hanno licenze a canone annuo — vedi tavola 02 del
piano di progetto. La Fase 2 lo evita: l'app manda il DWG a un server che l'utente ospita da solo
(`server/`, wrapper attorno a ODA File Converter, che invece e' gratuito ma non ridistribuibile) e
riceve indietro un DXF, che poi passa dallo stesso parser di sempre. Senza server configurato
nelle impostazioni, i DWG restano semplicemente non apribili — con un messaggio che lo dice,
non un errore oscuro.

## Limiti noti

- **Il DWG richiede di ospitare un server.** Vedi `server/README.md`: comporta procurarsi ODA
  File Converter da soli (licenza gratuita ma non ridistribuibile) e mantenere un piccolo servizio.
  Non c'e' un server gestito da Qualifix Service.
- **Scala non uniforme sui blocchi.** Un `INSERT` con scale X e Y diverse rende cerchi e archi con
  la scala media invece di trasformarli in ellissi. Sui disegni edili è un caso raro.
- **Tavolozza ACI approssimata** per gli indici 10–249: i primi nove colori, quelli che si usano
  davvero nelle tavole, sono esatti.
- **Il modulo `:app` non è stato compilato** nell'ambiente in cui è stato scritto (SDK Android e
  Maven di Google non raggiungibili): va aperto in Android Studio per la prima build.

## Disegno di esempio

`samples/locale-esempio.dxf` è una stanza 4,20 × 3,00 m con muri, porta con anta ad arco, finestra
e un tavolo tondo. È usato da `SampleDrawingTest` per verificare l'intero percorso: apertura del
file, aggancio allo spigolo interno, quotatura della parete (4000 mm) e del diametro del tavolo.
