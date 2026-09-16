import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Guardia contro i caratteri che il font impacchettato non sa disegnare.
///
/// L'app porta con sé Roboto per funzionare senza rete, ed è una versione
/// ridotta: 896 glifi, non tutto l'Unicode. Un carattere che non c'è non viene
/// scaricato da nessuna parte — esce un rettangolo vuoto, e basta. È già
/// successo tre volte (il pedice di `log₁₀`, la freccia `»` dell'ordine di
/// piega, il simbolo del tasto cancella) e ogni volta se n'è accorto soltanto
/// chi ha guardato lo schermo.
///
/// Invece di tenere una lista scritta a mano di cosa è permesso, questo test
/// legge il font vero e controlla ogni carattere dei sorgenti contro la sua
/// tabella dei caratteri. Così resta giusto da solo anche se un domani il font
/// cambia.
void main() {
  test('ogni carattere che finisce a schermo esiste nel font', () {
    final coperti = _caratteriDel('assets/fonts/Roboto-Regular.ttf');
    expect(coperti.length, greaterThan(200),
        reason: 'la lettura del font non è andata a buon fine');

    final colpevoli = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final righe = file.readAsLinesSync();
      for (var n = 0; n < righe.length; n++) {
        final riga = righe[n];
        // I commenti non finiscono a schermo.
        if (riga.trimLeft().startsWith('//')) continue;
        for (final rune in riga.runes) {
          // Sotto lo spazio ci sono solo caratteri di controllo.
          if (rune < 0x20 || coperti.contains(rune)) continue;
          final codice =
              'U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}';
          colpevoli.add('${file.path}:${n + 1}  $codice  '
              '«${String.fromCharCode(rune)}»');
        }
      }
    }

    expect(
      colpevoli,
      isEmpty,
      reason: 'Questi caratteri uscirebbero come rettangoli vuoti, perché il '
          'Roboto impacchettato non li contiene:\n${colpevoli.join('\n')}',
    );
  });
}

/// I codici Unicode che il font sa disegnare, letti dalla tabella `cmap`.
///
/// Parser minimo: bastano i formati 4 e 12, gli unici che i font Unicode usano
/// davvero, e serve solo sapere quali codici sono coperti — non a quale glifo
/// corrispondono.
Set<int> _caratteriDel(String percorso) {
  final dati = ByteData.sublistView(File(percorso).readAsBytesSync());
  final numeroTabelle = dati.getUint16(4);

  var offsetCmap = -1;
  for (var i = 0; i < numeroTabelle; i++) {
    final voce = 12 + i * 16;
    final nome = String.fromCharCodes(
      List.generate(4, (k) => dati.getUint8(voce + k)),
    );
    if (nome == 'cmap') {
      offsetCmap = dati.getUint32(voce + 8);
      break;
    }
  }
  if (offsetCmap < 0) return {};

  final coperti = <int>{};
  final sottotabelle = dati.getUint16(offsetCmap + 2);
  for (var i = 0; i < sottotabelle; i++) {
    final record = offsetCmap + 4 + i * 8;
    final inizio = offsetCmap + dati.getUint32(record + 4);
    final formato = dati.getUint16(inizio);

    if (formato == 4) {
      final mezziSegmenti = dati.getUint16(inizio + 6);
      final segmenti = mezziSegmenti ~/ 2;
      final fine = inizio + 14;
      final avvio = fine + mezziSegmenti + 2;
      for (var s = 0; s < segmenti; s++) {
        final da = dati.getUint16(avvio + s * 2);
        final a = dati.getUint16(fine + s * 2);
        if (da == 0xFFFF) continue;
        for (var c = da; c <= a && c != 0xFFFF; c++) {
          coperti.add(c);
        }
      }
    } else if (formato == 12) {
      final gruppi = dati.getUint32(inizio + 12);
      for (var g = 0; g < gruppi; g++) {
        final voce = inizio + 16 + g * 12;
        final da = dati.getUint32(voce);
        final a = dati.getUint32(voce + 4);
        for (var c = da; c <= a; c++) {
          coperti.add(c);
        }
      }
    }
  }
  return coperti;
}
