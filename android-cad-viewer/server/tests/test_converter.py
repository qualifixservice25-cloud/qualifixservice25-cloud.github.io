import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from converter import ConversionError, ConverterConfig, command_from_env, convert_dwg_to_dxf  # noqa: E402

FAKE_CONVERTER = os.path.join(os.path.dirname(__file__), "fixtures", "fake_converter.py")


def config(**overrides) -> ConverterConfig:
    base = {
        "command": [sys.executable, FAKE_CONVERTER],
        "output_version": "ACAD2010",
        "timeout_seconds": 5,
    }
    base.update(overrides)
    return ConverterConfig(**base)


class ConvertDwgToDxfTest(unittest.TestCase):
    def test_una_conversione_riuscita_restituisce_i_byte_del_dxf(self):
        result = convert_dwg_to_dxf(b"contenuto qualunque", config())
        self.assertIn(b"SECTION", result)

    def test_nessun_output_diventa_conversion_failed_non_server_fault(self):
        with self.assertRaises(ConversionError) as ctx:
            convert_dwg_to_dxf(b"TRIGGER_NO_OUTPUT", config())
        self.assertEqual("CONVERSION_FAILED", ctx.exception.code)
        self.assertFalse(ctx.exception.server_fault)

    def test_uscita_diversa_da_zero_diventa_conversion_failed_con_stderr_nel_messaggio(self):
        with self.assertRaises(ConversionError) as ctx:
            convert_dwg_to_dxf(b"TRIGGER_NONZERO_EXIT", config())
        self.assertEqual("CONVERSION_FAILED", ctx.exception.code)
        self.assertIn("errore finto del convertitore", ctx.exception.message)

    def test_timeout_diventa_un_errore_dedicato_non_server_fault(self):
        with self.assertRaises(ConversionError) as ctx:
            convert_dwg_to_dxf(b"TRIGGER_TIMEOUT", config(timeout_seconds=1))
        self.assertEqual("TIMEOUT", ctx.exception.code)
        self.assertFalse(ctx.exception.server_fault)

    def test_comando_inesistente_e_un_errore_di_configurazione_del_server(self):
        with self.assertRaises(ConversionError) as ctx:
            convert_dwg_to_dxf(b"qualunque", config(command=["/percorso/che/non/esiste"]))
        self.assertEqual("CONVERTER_NOT_FOUND", ctx.exception.code)
        self.assertTrue(ctx.exception.server_fault)

    def test_comando_vuoto_e_un_errore_di_configurazione_del_server(self):
        with self.assertRaises(ConversionError) as ctx:
            convert_dwg_to_dxf(b"qualunque", config(command=[]))
        self.assertEqual("CONVERTER_NOT_CONFIGURED", ctx.exception.code)
        self.assertTrue(ctx.exception.server_fault)


class CommandFromEnvTest(unittest.TestCase):
    def test_stringa_vuota_o_assente_da_lista_vuota(self):
        self.assertEqual([], command_from_env(None))
        self.assertEqual([], command_from_env("   "))

    def test_divide_rispettando_le_virgolette(self):
        self.assertEqual(
            ["xvfb-run", "-a", "/opt/ODA File Converter/ODAFileConverter"],
            command_from_env('xvfb-run -a "/opt/ODA File Converter/ODAFileConverter"'),
        )


if __name__ == "__main__":
    unittest.main()
