# Immagine per il server di conversione DWG -> DXF.
#
# Non include ODA File Converter: la sua licenza (gratuita, ma non ridistribuibile) impone di
# scaricarlo direttamente dal sito del produttore accettando la EULA. Questo Dockerfile si
# aspetta di trovarlo gia' scompattato in ./oda-file-converter/ accanto a questo file prima
# della build - vedi README.md per dove prenderlo.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        xvfb \
        libqt5widgets5 \
        libqt5gui5 \
        libqt5core5a \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY app.py converter.py multipart.py ./

# Il binario di ODA File Converter, procurato a parte (vedi commento sopra). Se la cartella non
# esiste la build fallisce qui invece che silenziosamente a runtime.
COPY oda-file-converter/ /opt/oda-file-converter/
RUN test -e /opt/oda-file-converter/ODAFileConverter || \
    (echo "server/oda-file-converter/ODAFileConverter non trovato: vedi server/README.md" && exit 1)
RUN chmod +x /opt/oda-file-converter/ODAFileConverter

ENV CONVERTER_CMD="xvfb-run -a /opt/oda-file-converter/ODAFileConverter"
ENV PORT=8080
EXPOSE 8080

CMD ["python3", "app.py"]
