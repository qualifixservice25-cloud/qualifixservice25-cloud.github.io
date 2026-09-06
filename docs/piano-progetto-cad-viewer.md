# Piano di progetto — Visualizzatore DXF con Quotatura (Android)

Nome dell'app: CAD Viewer · Package: `org.cadviewer.app`

Versione interattiva e completa del piano: https://claude.ai/code/artifact/7dc9b0ca-aa03-4055-b142-98313f6b92e0

## 1. Obiettivo e ambito

App che apre file DXF su smartphone o tablet e permette di eseguire quotature complete come un CAD desktop, per capocantiere, geometri e installatori che oggi devono tornare in ufficio per leggere o annotare un disegno.

Fuori ambito per la v1: editing di geometrie complesse, rendering 3D, collaborazione multi-utente in tempo reale. La v1 è un *viewer con motore di quotatura*, non un CAD di disegno completo.

## 2. Formati e librerie valutate

| Soluzione | Tipo | Copertura | Nota |
|---|---|---|---|
| Parser DXF proprio | Sviluppo interno | DXF | Fattibile: specifica DXF Reference è pubblica e gratuita. Percorso consigliato per l'MVP. |
| ODA Drawings SDK | Commerciale (C++/JNI) | DWG + DXF | Standard de facto CAD terze parti. Licenza a canone annuo. |
| ODA File Converter | Gratuito, da server | DWG → DXF | Converte DWG in DXF headless lato server: percorso più economico. |
| Aspose.CAD | Commerciale (Java) | DWG + DXF | SDK pronto all'uso, licenza per sviluppatore. |
| LibreDWG | Open source (GPL) | DWG parziale | Copertura incompleta sulle versioni recenti; licenza GPL vincolante. |

**Scelta fatta:** parser DXF in Kotlin, nessun costo di licenza. Il DWG è **fuori ambito**: la pipeline di conversione server-side, provata nella Fase 2, funzionava ma scaricava su chi pubblica l'app l'onere di mantenere un servizio, e su chi la usa quello di configurarlo — troppo per un'app che si apre in cantiere. Un DWG viene riconosciuto e rifiutato indicando di esportarlo in DXF. Se un domani i numeri giustificheranno la spesa, la strada dell'SDK commerciale resta aperta e non cambia il resto dell'architettura.

## 3. Architettura tecnica

- **Modello dati:** `Document → Layer[] → Entity[]` (Line, Polyline, Circle, Arc, Ellipse, Text, Insert). Le quote sono entità `Dimension` con proprio `DimensionStyle`, salvate come layer separato in overlay.
- **Rendering:** Canvas nativo Android con culling e level-of-detail; OpenGL ES (`GLSurfaceView`) come opzione futura per disegni molto pesanti.
- **Unità di misura:** lettura obbligatoria di `$INSUNITS` dall'header DXF — è il punto più critico del progetto (vedi rischi).

## 4. Motore di quotatura

Tipi di quota: lineare, allineata, angolare, radiale/diametro, concatenate/baseline, con tolleranze in stile ISO.

**Snap engine** indispensabile: aggancio a punto finale, punto medio, centro, intersezione, quadrante — senza questo, la quotatura su touchscreen è inutilizzabile in ambito professionale.

**Misura per entità:** toccare una linea ne dà la lunghezza, toccarne un'altra dà la distanza fra le due. È un tocco invece di due o tre, ed è il modo in cui si legge un disegno quando si ha una mano occupata.

## 5. Interfaccia e interazione

- Gesture: pinch zoom, due dita pan, tap per snap/selezione, tap prolungato per menu contestuale.
- Pannello layer con visibilità/blocco/colore.
- Barra strumenti quota dedicata.
- Modalità cantiere: tema scuro ad alto contrasto, testo quote ingrandito.
- Indicatore scala/unità sempre visibile.

## 6. Stack tecnologico

Kotlin · Jetpack Compose (UI chrome) · Canvas nativo Android per il disegno CAD · parser DXF interno · Room (persistenza progetti) · Storage Access Framework · PdfDocument API + writer DXF per l'export · AdMob + Play Billing per la monetizzazione.

## 7. Roadmap e fasi (stima part-time, un solo sviluppatore)

| Fase | Contenuto | Durata |
|---|---|---|
| 0 | Ricerca e proof of concept sul parser DXF | 2 sett. |
| 1 | Viewer DXF di base (parsing, pan/zoom, layer) | 4 sett. |
| 2 | ~~Supporto DWG (pipeline di conversione)~~ — abbandonata | — |
| 3 | Motore di quotatura (snap + tutti i tipi di quota) | 5 sett. |
| 4 | Export e persistenza progetti | 2 sett. |
| 5 | UI, monetizzazione, localizzazione | 2 sett. |
| 6 | Beta testing e pubblicazione Play Store | 2 sett. |

**Totale stimato:** ≈ 17 settimane (4 mesi), tolta la Fase 2.

## 8. Rischi principali

- **Formato DWG proprietario:** chiuso, in evoluzione e costoso da leggere — evitato limitandosi al DXF.
- **Unità di misura errate:** un `$INSUNITS` letto male produce quote sbagliate senza errore visibile — rischio reputazionale più alto del progetto.
- **Performance su disegni pesanti:** culling e level-of-detail vanno progettati fin dalla Fase 1.
- **Costo licenze SDK:** ODA/Aspose hanno canoni annuali che possono superare il budget indie — per questo si parte dal parser DXF proprio.

## 9. Modello di business

Versione gratuita con AdMob e limite di 5 quote per disegno o watermark sull'export; versione Pro (Play Billing) con quote illimitate ed export senza watermark.

## Stato dell'implementazione

Il codice sta in [`android-cad-viewer/`](../android-cad-viewer/README.md).

| Fase | Stato |
|---|---|
| 0 — Ricerca e proof of concept | Fatta: parser DXF proprio, validato su un disegno di esempio |
| 1 — Viewer DXF di base | Fatta: parsing, layer, blocchi, rendering con culling, pan/zoom |
| 2 — Supporto DWG | Abbandonata: solo DXF, un DWG viene rifiutato con l'indicazione di esportarlo |
| 3 — Motore di quotatura | Fatta: snap engine, tutti i tipi di quota, serie concatenate e da linea base, misura per entità |
| 4 — Export e progetti | Export DXF R12 e PDF fatti; salvataggio progetti locali da fare |
| 5 — UI, monetizzazione, localizzazione | UI e traduzione IT/EN fatte; AdMob e Play Billing da fare |
| 6 — Beta testing e pubblicazione | Da fare |

88 test unitari (core, JVM) coprono parser, geometria, unità di misura, snap, quotature e la
misura per entità.

**Perché la Fase 2 è stata abbandonata dopo essere stata scritta:** il server di conversione
funzionava, ma non era gestito da nessuno — ognuno avrebbe dovuto ospitare la propria istanza,
procurarsi ODA File Converter e configurarne l'indirizzo nell'app prima di poter aprire un file.
Per un'app che si usa in cantiere è un prezzo troppo alto rispetto all'esportare il disegno in DXF
una volta sola. Se un domani i numeri giustificheranno la licenza di un SDK che legge il DWG sul
telefono, il parser e il motore di quotatura restano quelli: cambia solo da dove arrivano le
entità.

## 10. Prossimi passi

1. Raccogliere 2–3 disegni DXF reali per testare il parser su dati veri.
2. Salvataggio dei progetti in locale (Fase 4), che è anche il presupposto della versione Pro.
3. AdMob e Play Billing (Fase 5).
