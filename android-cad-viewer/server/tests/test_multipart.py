import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from multipart import MultipartError, parse_multipart  # noqa: E402


def build_body(boundary: str, filename: str, content: bytes, extra_field: tuple[str, str] | None = None) -> bytes:
    parts = []
    if extra_field:
        name, value = extra_field
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
            f"{value}\r\n".encode("utf-8"),
        )
    parts.append(
        (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
            "Content-Type: application/octet-stream\r\n\r\n"
        ).encode("utf-8")
        + content
        + b"\r\n",
    )
    parts.append(f"--{boundary}--\r\n".encode("utf-8"))
    return b"".join(parts)


class ParseMultipartTest(unittest.TestCase):
    def test_estrae_il_file_con_nome_e_contenuto(self):
        body = build_body("BOUND1", "muro.dwg", b"AC1027-contenuto-finto")
        files = parse_multipart(body, "multipart/form-data; boundary=BOUND1")

        self.assertIn("file", files)
        self.assertEqual("muro.dwg", files["file"].filename)
        self.assertEqual(b"AC1027-contenuto-finto", files["file"].content)
        self.assertEqual("application/octet-stream", files["file"].content_type)

    def test_contenuto_binario_con_byte_qualunque_non_viene_troncato(self):
        binary = bytes(range(256)) * 4
        body = build_body("B2", "a.dwg", binary)
        files = parse_multipart(body, "multipart/form-data; boundary=B2")

        self.assertEqual(binary, files["file"].content)

    def test_piu_campi_vengono_distinti_per_nome(self):
        body = build_body("B3", "a.dwg", b"contenuto", extra_field=("note", "rilievo cantiere"))
        files = parse_multipart(body, "multipart/form-data; boundary=B3")

        self.assertEqual(2, len(files))
        self.assertEqual(b"contenuto", files["file"].content)
        self.assertEqual(b"rilievo cantiere", files["note"].content)

    def test_content_type_non_multipart_solleva_errore(self):
        with self.assertRaises(MultipartError):
            parse_multipart(b"qualunque cosa", "application/json")

    def test_content_type_senza_boundary_solleva_errore(self):
        with self.assertRaises(MultipartError):
            parse_multipart(b"qualunque cosa", "multipart/form-data")

    def test_corpo_vuoto_restituisce_nessun_file_senza_eccezioni(self):
        files = parse_multipart(b"", "multipart/form-data; boundary=X")
        self.assertEqual({}, files)


if __name__ == "__main__":
    unittest.main()
