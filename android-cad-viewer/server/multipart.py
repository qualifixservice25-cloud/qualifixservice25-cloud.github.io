"""Parsing di richieste multipart/form-data, scritto a mano.

Il modulo cgi (che faceva questo lavoro nella libreria standard) e' deprecato dalla 3.11 e
rimosso dalla 3.13, quindi appoggiarcisi avrebbe reso il server fragile rispetto alla versione
di Python installata su chi lo ospita. Il formato multipart che ci serve e' comunque piccolo:
un solo campo file, nessun campo di testo, nessun parametro annidato.
"""

from __future__ import annotations

from dataclasses import dataclass


class MultipartError(ValueError):
    """Corpo che non rispetta la sintassi multipart/form-data attesa."""


@dataclass
class MultipartFile:
    field_name: str
    filename: str
    content_type: str
    content: bytes


def boundary_from_content_type(content_type: str | None) -> str:
    if not content_type or "multipart/form-data" not in content_type:
        raise MultipartError("Content-Type non e' multipart/form-data")
    for part in content_type.split(";"):
        part = part.strip()
        if part.startswith("boundary="):
            value = part[len("boundary="):]
            return value.strip('"')
    raise MultipartError("Nessun boundary dichiarato nel Content-Type")


def parse_multipart(body: bytes, content_type: str | None) -> dict[str, MultipartFile]:
    boundary = boundary_from_content_type(content_type)
    delimiter = b"--" + boundary.encode("ascii", errors="strict")

    # Ogni parte sta fra due occorrenze del delimiter; l'ultima e' seguita da "--" e non da CRLF.
    segments = body.split(delimiter)
    files: dict[str, MultipartFile] = {}

    for segment in segments[1:-1]:
        # Dopo il delimiter c'e' sempre un CRLF prima delle intestazioni della parte.
        if segment.startswith(b"\r\n"):
            segment = segment[2:]
        elif segment.startswith(b"\n"):
            segment = segment[1:]

        header_end = segment.find(b"\r\n\r\n")
        header_sep_len = 4
        if header_end == -1:
            header_end = segment.find(b"\n\n")
            header_sep_len = 2
        if header_end == -1:
            continue  # parte senza intestazioni, es. residuo di spaziatura: si ignora.

        header_block = segment[:header_end].decode("utf-8", errors="replace")
        content = segment[header_end + header_sep_len:]
        # Il CRLF finale prima del prossimo delimiter appartiene al separatore, non al contenuto.
        if content.endswith(b"\r\n"):
            content = content[:-2]
        elif content.endswith(b"\n"):
            content = content[:-1]

        field_name = None
        filename = ""
        part_content_type = "application/octet-stream"
        for line in header_block.split("\r\n" if "\r\n" in header_block else "\n"):
            line = line.strip()
            if not line:
                continue
            key, _, value = line.partition(":")
            key = key.strip().lower()
            value = value.strip()
            if key == "content-disposition":
                field_name, filename = _parse_content_disposition(value)
            elif key == "content-type":
                part_content_type = value

        if field_name is None:
            continue

        files[field_name] = MultipartFile(
            field_name=field_name,
            filename=filename,
            content_type=part_content_type,
            content=content,
        )

    return files


def _parse_content_disposition(value: str) -> tuple[str | None, str]:
    name = None
    filename = ""
    for token in value.split(";"):
        token = token.strip()
        if token.startswith("name="):
            name = token[len("name="):].strip('"')
        elif token.startswith("filename="):
            filename = token[len("filename="):].strip('"')
    return name, filename
