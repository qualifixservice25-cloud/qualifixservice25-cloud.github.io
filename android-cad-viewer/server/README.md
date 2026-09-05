# Server di conversione DWG → DXF

Wrapper minimo attorno a **ODA File Converter**: riceve un DWG dall'app Android, lo converte in
DXF e restituisce il risultato. Serve perché il formato DWG è proprietario e chiuso — l'app apre
solo DXF nativamente (vedi `../core/src/main/kotlin/org/qualifix/cad/core/dxf/`); questo server è
il modo per supportare il DWG **senza pagare una licenza SDK** (vedi tavola 02 del piano di
progetto, `../../docs/piano-progetto-cad-viewer.md`).

Nessuna dipendenza oltre alla libreria standard di Python: niente Flask, niente framework HTTP.
Per un servizio che fa una cosa sola, riceve file ed esegue un programma esterno, tirare dentro
un framework avrebbe aggiunto superficie senza aggiungere niente di utile.

## Quello che devi procurarti da solo

**ODA File Converter è gratuito, ma la sua licenza non ne permette la ridistribuzione.** Questo
repository non lo contiene e non può scaricarlo per te. Vai su
https://www.opendesign.com/guestfiles/oda_file_converter, accetta la licenza del produttore e
scarica la build Linux. Scompatta il contenuto in `server/oda-file-converter/`, in modo che
`server/oda-file-converter/ODAFileConverter` esista — è il percorso che il `Dockerfile` si
aspetta. Quella cartella è nel `.gitignore`: non finisce mai in un commit.

## Avviarlo in locale, senza Docker

Utile per provare il flusso prima di occuparsi del deploy:

```bash
cd server
export CONVERTER_CMD="xvfb-run -a /percorso/a/ODAFileConverter"
python3 app.py
```

Verifica che risponda:

```bash
curl http://localhost:8080/health          # -> ok
curl -F "file=@disegno.dwg" http://localhost:8080/v1/convert -o disegno.dxf
```

## Avviarlo con Docker (il percorso consigliato per un deploy vero)

```bash
cd server
cp .env.example .env        # poi modifica CONVERTER_API_KEY
docker compose up --build -d
```

Il server ascolta su `:8080`. Mettilo dietro un reverse proxy con HTTPS (Caddy, Nginx, Traefik)
se lo esponi oltre alla tua rete locale: l'app Android carica un DWG a testa, non è un dato
sensibile in senso stretto, ma passarlo in chiaro su internet non è comunque una buona idea.

## Configurazione (variabili d'ambiente)

| Variabile | Default | Significato |
|---|---|---|
| `CONVERTER_CMD` | `xvfb-run -a ODAFileConverter` | Comando che lancia il convertitore. `xvfb-run` gli da' un display virtuale: ODA File Converter è un'app Qt e su Linux lo richiede anche da riga di comando. |
| `CONVERTER_API_KEY` | *(nessuna)* | Se impostata, il server rifiuta le richieste senza l'intestazione `X-Api-Key` corrispondente. **Impostala sempre se il server è raggiungibile da fuori la tua rete.** |
| `MAX_UPLOAD_MB` | `200` | Limite di dimensione per il file caricato. |
| `CONVERT_TIMEOUT_SECONDS` | `120` | Tempo massimo per una conversione prima di rispondere con `TIMEOUT`. |
| `OUTPUT_VERSION` | `ACAD2010` | Versione DXF di output richiesta a ODA File Converter. |
| `PORT` | `8080` | Porta di ascolto. |

## Protocollo

Un solo endpoint utile:

**`POST /v1/convert`** — corpo `multipart/form-data` con un campo `file` (il DWG).

- **200**: corpo binario, il DXF convertito (`Content-Type: application/dxf`).
- **Qualunque errore**: corpo `text/plain`, prima riga = codice macchina, resto = messaggio.
  Esempio: `CONVERSION_FAILED\nIl file DWG sembra danneggiato`.

| Status | Codice | Quando |
|---|---|---|
| 400 | `BAD_REQUEST` | Corpo non multipart, o senza campo `file` |
| 401 | `UNAUTHORIZED` | `CONVERTER_API_KEY` impostata e chiave assente/errata |
| 413 | `TOO_LARGE` | File oltre `MAX_UPLOAD_MB` |
| 422 | `CONVERSION_FAILED` / `TIMEOUT` | Il DWG caricato non si converte (corrotto, troppo pesante) |
| 500 | `CONVERTER_NOT_FOUND` / `CONVERTER_NOT_CONFIGURED` / `INTERNAL` | Problema di installazione del server, non del file dell'utente |

`GET /health` risponde `200 ok`, utile per il probe di un orchestratore.

Il client Android che parla questo protocollo è
`core/src/main/kotlin/org/qualifix/cad/core/dwg/DwgConversionClient.kt`.

## Test

Solo libreria standard, nessuna dipendenza da installare:

```bash
cd server
python3 -m unittest discover -s tests -v
```

I test del convertitore e del server usano un finto ODA File Converter
(`tests/fixtures/fake_converter.py`, la stessa firma da riga di comando del vero programma) e
non richiedono ne' Docker ne' il binario vero.

## Limiti noti

- Nessuna coda: le richieste sono servite dal `ThreadingHTTPServer` della libreria standard, un
  thread a richiesta. Va benissimo per un uso da un singolo cantiere o piccolo studio; per molti
  utenti simultanei serve mettere un proxy con limitazione di frequenza davanti.
- Nessun antivirus sui file caricati. Se il server è raggiungibile da internet, la chiave API è
  l'unica difesa: impostala sempre in quel caso.
- Non è un servizio gestito da Qualifix Service: ognuno ospita la propria istanza. È la scelta
  che evita di dover pagare una licenza SDK (vedi piano di progetto), a costo di dover mantenere
  un piccolo server da soli.
