# Piano di progetto — Visualizzatore DWG/DXF con Quotatura (Android)

Editore: Qualifix Service · Prodotto affine: Calcolo Cartongesso
Package suggerito: `org.qualifix.service.cadviewer`

Versione interattiva e completa del piano: https://claude.ai/code/artifact/7dc9b0ca-aa03-4055-b142-98313f6b92e0

## 1. Obiettivo e ambito

App che apre file DWG/DXF su smartphone o tablet e permette di eseguire quotature complete come un CAD desktop, per capocantiere, geometri e installatori che oggi devono tornare in ufficio per leggere o annotare un disegno.

Fuori ambito per la v1: editing di geometrie complesse, rendering 3D, collaborazione multi-utente in tempo reale. La v1 è un *viewer con motore di quotatura*, non un CAD di disegno completo.

## 2. Formati DWG/DXF e librerie

| Soluzione | Tipo | Copertura | Nota |
|---|---|---|---|
| Parser DXF proprio | Sviluppo interno | DXF | Fattibile: specifica DXF Reference è pubblica e gratuita. Percorso consigliato per l'MVP. |
| ODA Drawings SDK | Commerciale (C++/JNI) | DWG + DXF | Standard de facto CAD terze parti. Licenza a canone annuo. |
| ODA File Converter | Gratuito, da server | DWG → DXF | Converte DWG in DXF headless lato server: percorso più economico. |
| Aspose.CAD | Commerciale (Java) | DWG + DXF | SDK pronto all'uso, licenza per sviluppatore. |
| LibreDWG | Open source (GPL) | DWG parziale | Copertura incompleta sulle versioni recenti; licenza GPL vincolante. |

**Raccomandazione:** parser DXF in Kotlin per l'MVP (nessun costo di licenza). DWG in Fase 2 via pipeline di conversione server-side con ODA File Converter, rimandando l'eventuale spesa SDK a quando l'app ha utenti reali.

## 3. Architettura tecnica

- **Modello dati:** `Document → Layer[] → Entity[]` (Line, Polyline, Circle, Arc, Ellipse, Text, Insert). Le quote sono entità `Dimension` con proprio `DimensionStyle`, salvate come layer separato in overlay.
- **Rendering:** Canvas nativo Android con culling e level-of-detail; OpenGL ES (`GLSurfaceView`) come opzione futura per disegni molto pesanti.
- **Unità di misura:** lettura obbligatoria di `$INSUNITS` dall'header DXF — è il punto più critico del progetto (vedi rischi).

## 4. Motore di quotatura

Tipi di quota: lineare, allineata, angolare, radiale/diametro, concatenate/baseline, con tolleranze in stile ISO.

**Snap engine** indispensabile: aggancio a punto finale, punto medio, centro, intersezione, quadrante — senza questo, la quotatura su touchscreen è inutilizzabile in ambito professionale.

## 5. Interfaccia e interazione

- Gesture: pinch zoom, due dita pan, tap per snap/selezione, tap prolungato per menu contestuale.
- Pannello layer con visibilità/blocco/colore.
- Barra strumenti quota dedicata.
- Modalità cantiere: tema scuro ad alto contrasto, testo quote ingrandito.
- Indicatore scala/unità sempre visibile.

## 6. Stack tecnologico

Kotlin · Jetpack Compose (UI chrome) · Canvas nativo Android per il disegno CAD · parser DXF interno · conversione DWG via ODA File Converter server-side · Room (persistenza progetti) · Storage Access Framework · PdfDocument API + writer DXF per l'export · AdMob + Play Billing per la monetizzazione.

## 7. Roadmap e fasi (stima part-time, un solo sviluppatore)

| Fase | Contenuto | Durata |
|---|---|---|
| 0 | Ricerca e proof of concept sul parser DXF | 2 sett. |
| 1 | Viewer DXF di base (parsing, pan/zoom, layer) | 4 sett. |
| 2 | Supporto DWG (pipeline di conversione) | 3 sett. |
| 3 | Motore di quotatura (snap + tutti i tipi di quota) | 5 sett. |
| 4 | Export e persistenza progetti | 2 sett. |
| 5 | UI, monetizzazione, localizzazione | 2 sett. |
| 6 | Beta testing e pubblicazione Play Store | 2 sett. |

**Totale stimato:** ≈ 20 settimane (5 mesi).

## 8. Rischi principali

- **Formato DWG proprietario:** chiuso e in evoluzione — mitigato con pipeline ODA invece di reverse engineering proprio.
- **Unità di misura errate:** un `$INSUNITS` letto male produce quote sbagliate senza errore visibile — rischio reputazionale più alto del progetto.
- **Performance su disegni pesanti:** culling e level-of-detail vanno progettati fin dalla Fase 1.
- **Costo licenze SDK:** ODA/Aspose hanno canoni annuali che possono superare il budget indie — per questo si parte dal parser DXF proprio.

## 9. Modello di business

Stesso schema di Calcolo Cartongesso: versione gratuita con AdMob e limite di 5 quote per disegno o watermark sull'export; versione Pro (Play Billing) con quote illimitate, export senza watermark e supporto DWG completo.

## 10. Prossimi passi

1. Decidere lo scope dell'MVP (solo DXF vs DXF+DWG dal giorno uno).
2. Raccogliere 2–3 disegni DXF reali per testare il parser su dati veri.
3. Richiedere una quotazione a Open Design Alliance o valutare la trial di Aspose.CAD.
4. Registrare il naming `org.qualifix.service.cadviewer`, coerente con il brand già pubblicato.
