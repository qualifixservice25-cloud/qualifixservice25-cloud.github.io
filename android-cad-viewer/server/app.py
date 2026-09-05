#!/usr/bin/env python3
"""Server di conversione DWG -> DXF, da ospitare da soli accanto all'app Android.

Espone un solo endpoint utile, POST /v1/convert: riceve un DWG in multipart/form-data, lo passa
a ODA File Converter (vedi converter.py) e restituisce il DXF prodotto. Non usa nessuna
libreria oltre alla standard library di Python, cosi' l'unica cosa da installare su chi lo
ospita e' Python stesso (o l'immagine Docker fornita, che se la porta dietro).

Protocollo di errore (vedi anche core/.../dwg/DwgConversionClient.kt sul lato Android):
corpo text/plain, prima riga = codice macchina, righe successive = messaggio per l'utente.
"""

from __future__ import annotations

import logging
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from converter import ConversionError, ConverterConfig, command_from_env, convert_dwg_to_dxf
from multipart import MultipartError, parse_multipart

logger = logging.getLogger("qualifix-cad-converter")


class Settings:
    def __init__(self, env: dict[str, str]):
        self.port = int(env.get("PORT", "8080"))
        self.api_key = env.get("CONVERTER_API_KEY", "").strip() or None
        self.max_upload_bytes = int(env.get("MAX_UPLOAD_MB", "200")) * 1024 * 1024
        self.converter = ConverterConfig(
            command=command_from_env(env.get("CONVERTER_CMD", "xvfb-run -a ODAFileConverter")),
            output_version=env.get("OUTPUT_VERSION", "ACAD2010"),
            timeout_seconds=int(env.get("CONVERT_TIMEOUT_SECONDS", "120")),
        )


class ConvertHandler(BaseHTTPRequestHandler):
    settings: Settings  # impostato da make_server prima di avviare il server

    server_version = "QualifixCadConverter/1.0"

    def log_message(self, format: str, *args) -> None:  # noqa: A002 - firma imposta dalla stdlib
        logger.info("%s - %s", self.address_string(), format % args)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._write_text(200, "ok")
        else:
            self._write_error(404, "NOT_FOUND", "Percorso inesistente")

    def do_POST(self) -> None:
        if self.path != "/v1/convert":
            self._write_error(404, "NOT_FOUND", "Percorso inesistente")
            return

        if self.settings.api_key is not None:
            provided = self.headers.get("X-Api-Key", "")
            if provided != self.settings.api_key:
                self._write_error(401, "UNAUTHORIZED", "Chiave API mancante o errata")
                return

        length = self._content_length()
        if length is None:
            self._write_error(400, "BAD_REQUEST", "Intestazione Content-Length mancante")
            return
        if length > self.settings.max_upload_bytes:
            self._write_error(
                413,
                "TOO_LARGE",
                f"File troppo grande: il limite del server e' "
                f"{self.settings.max_upload_bytes // (1024 * 1024)} MB",
            )
            return

        body = self.rfile.read(length)

        try:
            files = parse_multipart(body, self.headers.get("Content-Type"))
        except MultipartError as error:
            self._write_error(400, "BAD_REQUEST", f"Corpo della richiesta non valido: {error}")
            return

        uploaded = files.get("file")
        if uploaded is None or not uploaded.content:
            self._write_error(400, "BAD_REQUEST", "Nessun file nel campo 'file'")
            return

        try:
            dxf_bytes = convert_dwg_to_dxf(uploaded.content, self.settings.converter)
        except ConversionError as error:
            status = 500 if error.server_fault else 422
            if error.server_fault:
                logger.error("Errore di configurazione del server: %s", error.message)
            self._write_error(status, error.code, error.message)
            return
        except Exception:  # difesa: un bug nel convertitore non deve far cadere il thread
            logger.exception("Errore inatteso durante la conversione")
            self._write_error(500, "INTERNAL", "Errore interno del server")
            return

        self._write_binary(200, "application/dxf", dxf_bytes)

    def _content_length(self) -> int | None:
        raw = self.headers.get("Content-Length")
        if raw is None:
            return None
        try:
            return int(raw)
        except ValueError:
            return None

    def _write_text(self, status: int, text: str) -> None:
        self._write_binary(status, "text/plain; charset=utf-8", text.encode("utf-8"))

    def _write_error(self, status: int, code: str, message: str) -> None:
        self._write_text(status, f"{code}\n{message}")

    def _write_binary(self, status: int, content_type: str, payload: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


def make_server(settings: Settings) -> ThreadingHTTPServer:
    handler = type("BoundConvertHandler", (ConvertHandler,), {"settings": settings})
    return ThreadingHTTPServer(("0.0.0.0", settings.port), handler)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    settings = Settings(os.environ)
    if settings.api_key is None:
        logger.warning(
            "CONVERTER_API_KEY non impostata: chiunque raggiunga questo indirizzo puo' "
            "convertire file. Va bene su una rete privata, non se il server e' esposto su "
            "internet.",
        )
    server = make_server(settings)
    logger.info("In ascolto sulla porta %d", settings.port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        sys.exit(0)


if __name__ == "__main__":
    main()
