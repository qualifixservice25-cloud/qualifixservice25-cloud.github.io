"""Wrapper attorno a ODA File Converter: lo invoca da riga di comando su una cartella temporanea.

ODA File Converter e' gratuito ma la sua licenza non ne permette la ridistribuzione: questo
modulo non lo scarica ne' lo installa, si limita a lanciarlo. Chi ospita il server deve
procurarselo da https://www.opendesign.com/guestfiles/oda_file_converter (accettando la EULA
del produttore) e indicarne il percorso in CONVERTER_CMD (vedi README.md).
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass


class ConversionError(Exception):
    """Errore di conversione, con un codice macchina stabile e un messaggio per l'utente.

    server_fault distingue un problema di installazione del server (converter_cmd sbagliato,
    binario assente) da un problema del singolo file caricato (DWG corrotto, versione non
    supportata): il primo e' un 500, il secondo e' un 422 che l'app puo' mostrare cosi' com'e'.
    """

    def __init__(self, code: str, message: str, *, server_fault: bool = False):
        super().__init__(message)
        self.code = code
        self.message = message
        self.server_fault = server_fault


@dataclass
class ConverterConfig:
    # Es. ["xvfb-run", "-a", "ODAFileConverter"]: ODA File Converter e' un'applicazione Qt e su
    # Linux richiede un display, anche solo per convertire da riga di comando.
    command: list[str]
    output_version: str = "ACAD2010"
    timeout_seconds: int = 120


# Firma da riga di comando di ODA File Converter su Linux/macOS:
#   ODAFileConverter <cartella-input> <cartella-output> <versione-output> <tipo-output> <ricorsivo> <audit>
def convert_dwg_to_dxf(dwg_bytes: bytes, config: ConverterConfig) -> bytes:
    if not config.command:
        raise ConversionError(
            "CONVERTER_NOT_CONFIGURED",
            "CONVERTER_CMD non e' impostata sul server",
            server_fault=True,
        )

    with tempfile.TemporaryDirectory(prefix="qualifix-cad-") as workdir:
        input_dir = os.path.join(workdir, "in")
        output_dir = os.path.join(workdir, "out")
        os.makedirs(input_dir)
        os.makedirs(output_dir)

        input_path = os.path.join(input_dir, "input.dwg")
        with open(input_path, "wb") as handle:
            handle.write(dwg_bytes)

        command = [
            *config.command,
            input_dir,
            output_dir,
            config.output_version,
            "DXF",
            "0",  # non ricorsivo: una cartella con un solo file
            "1",  # audit: corregge piccole incongruenze invece di rifiutare il file
        ]

        try:
            result = subprocess.run(
                command,
                capture_output=True,
                timeout=config.timeout_seconds,
            )
        except FileNotFoundError as error:
            raise ConversionError(
                "CONVERTER_NOT_FOUND",
                f"Eseguibile del convertitore non trovato: {error.filename}",
                server_fault=True,
            ) from error
        except subprocess.TimeoutExpired as error:
            raise ConversionError(
                "TIMEOUT",
                "La conversione ha impiegato troppo tempo: il file potrebbe essere troppo "
                "grande o troppo complesso",
            ) from error

        produced = [name for name in os.listdir(output_dir) if name.lower().endswith(".dxf")]
        if not produced:
            stderr_tail = result.stderr.decode("utf-8", errors="replace").strip()[-2000:]
            detail = "Il convertitore non ha prodotto un file DXF"
            if stderr_tail:
                detail += f": {stderr_tail}"
            raise ConversionError("CONVERSION_FAILED", detail)

        with open(os.path.join(output_dir, produced[0]), "rb") as handle:
            return handle.read()


def command_from_env(raw: str | None) -> list[str]:
    """CONVERTER_CMD e' una stringa (es. "xvfb-run -a ODAFileConverter"), non un array:
    e' piu' facile da scrivere in un .env o in un docker-compose.yml di una lista JSON.
    shlex gestisce anche le virgolette, utile per percorsi con spazi."""
    if not raw or not raw.strip():
        return []
    import shlex

    return shlex.split(raw)


def which_or_none(name: str) -> str | None:
    return shutil.which(name)
