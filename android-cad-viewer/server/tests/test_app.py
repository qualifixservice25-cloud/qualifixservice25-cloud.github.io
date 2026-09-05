import http.client
import os
import sys
import threading
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app import Settings, make_server  # noqa: E402
from converter import ConverterConfig  # noqa: E402
from test_multipart import build_body  # noqa: E402

FAKE_CONVERTER = os.path.join(os.path.dirname(__file__), "fixtures", "fake_converter.py")


class RunningServer:
    """Il server vero, in un thread, su una porta scelta dal sistema operativo."""

    def __init__(self, *, api_key: str | None = None, max_upload_bytes: int = 200 * 1024 * 1024):
        settings = Settings.__new__(Settings)  # non passiamo da os.environ nei test
        settings.port = 0
        settings.api_key = api_key
        settings.max_upload_bytes = max_upload_bytes
        settings.converter = ConverterConfig(command=[sys.executable, FAKE_CONVERTER], timeout_seconds=5)
        self._server = make_server(settings)
        self.port = self._server.server_address[1]
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()

    def close(self) -> None:
        self._server.shutdown()
        self._server.server_close()

    def request(self, method: str, path: str, body: bytes = b"", headers: dict[str, str] | None = None):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        try:
            conn.request(method, path, body=body, headers=headers or {})
            response = conn.getresponse()
            payload = response.read()
            return response.status, dict(response.getheaders()), payload
        finally:
            conn.close()


def multipart_headers_and_body(filename: str, content: bytes) -> tuple[dict[str, str], bytes]:
    body = build_body("TESTBOUND", filename, content)
    headers = {
        "Content-Type": "multipart/form-data; boundary=TESTBOUND",
        "Content-Length": str(len(body)),
    }
    return headers, body


class AppEndToEndTest(unittest.TestCase):
    def setUp(self):
        self.server = RunningServer()

    def tearDown(self):
        self.server.close()

    def test_health_risponde_ok(self):
        status, _, body = self.server.request("GET", "/health")
        self.assertEqual(200, status)
        self.assertEqual(b"ok", body)

    def test_conversione_riuscita_restituisce_il_dxf(self):
        headers, body = multipart_headers_and_body("muro.dwg", b"contenuto qualunque")
        status, response_headers, payload = self.server.request("POST", "/v1/convert", body, headers)

        self.assertEqual(200, status)
        self.assertEqual("application/dxf", response_headers["Content-Type"])
        self.assertIn(b"SECTION", payload)

    def test_richiesta_senza_campo_file_e_un_bad_request(self):
        body = build_body("TESTBOUND", "muro.dwg", b"x").replace(b'name="file"', b'name="altro"')
        headers = {"Content-Type": "multipart/form-data; boundary=TESTBOUND", "Content-Length": str(len(body))}
        status, _, payload = self.server.request("POST", "/v1/convert", body, headers)

        self.assertEqual(400, status)
        self.assertTrue(payload.startswith(b"BAD_REQUEST\n"))

    def test_conversione_fallita_e_un_422_con_codice_conversion_failed(self):
        headers, body = multipart_headers_and_body("rotto.dwg", b"TRIGGER_NO_OUTPUT")
        status, _, payload = self.server.request("POST", "/v1/convert", body, headers)

        self.assertEqual(422, status)
        self.assertTrue(payload.startswith(b"CONVERSION_FAILED\n"))

    def test_percorso_sconosciuto_e_un_404(self):
        status, _, _ = self.server.request("GET", "/qualunque")
        self.assertEqual(404, status)


class AppApiKeyTest(unittest.TestCase):
    def setUp(self):
        self.server = RunningServer(api_key="segreto-123")

    def tearDown(self):
        self.server.close()

    def test_senza_chiave_e_un_401(self):
        headers, body = multipart_headers_and_body("a.dwg", b"contenuto")
        status, _, payload = self.server.request("POST", "/v1/convert", body, headers)

        self.assertEqual(401, status)
        self.assertTrue(payload.startswith(b"UNAUTHORIZED\n"))

    def test_con_la_chiave_corretta_passa(self):
        headers, body = multipart_headers_and_body("a.dwg", b"contenuto")
        headers["X-Api-Key"] = "segreto-123"
        status, _, _ = self.server.request("POST", "/v1/convert", body, headers)

        self.assertEqual(200, status)


class AppUploadLimitTest(unittest.TestCase):
    def test_un_file_oltre_il_limite_e_un_413(self):
        server = RunningServer(max_upload_bytes=10)
        try:
            headers, body = multipart_headers_and_body("a.dwg", b"molto piu' di dieci byte di contenuto")
            status, _, payload = server.request("POST", "/v1/convert", body, headers)

            self.assertEqual(413, status)
            self.assertTrue(payload.startswith(b"TOO_LARGE\n"))
        finally:
            server.close()


if __name__ == "__main__":
    unittest.main()
