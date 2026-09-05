#!/usr/bin/env python3
"""Finto ODA File Converter per i test: stessa firma da riga di comando del vero programma,
ma il comportamento lo decide il contenuto del file in ingresso invece che il file stesso,
cosi' i test non devono avere un vero DWG a disposizione.
"""

from __future__ import annotations

import os
import sys
import time


def main() -> None:
    input_dir, output_dir = sys.argv[1], sys.argv[2]
    with open(os.path.join(input_dir, "input.dwg"), "rb") as handle:
        content = handle.read()

    if content == b"TRIGGER_TIMEOUT":
        time.sleep(5)
        return
    if content == b"TRIGGER_NO_OUTPUT":
        return
    if content == b"TRIGGER_NONZERO_EXIT":
        sys.stderr.write("errore finto del convertitore\n")
        sys.exit(2)

    with open(os.path.join(output_dir, "input.dxf"), "wb") as handle:
        handle.write(b"0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF\n")


if __name__ == "__main__":
    main()
