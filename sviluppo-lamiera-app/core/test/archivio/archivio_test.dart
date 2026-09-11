import 'dart:io';

import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';
import 'package:test/test.dart';

void main() {
  group("Andata e ritorno dell'inventario", () {
    test('il catalogo standard sopravvive al salvataggio', () {
      final originale = CatalogoStandard.inventario();
      final riletto =
          ArchivioJson.inventarioDaTesto(ArchivioJson.inventarioATesto(originale));

      expect(riletto, isNotNull);
      expect(riletto!.punzoni, hasLength(originale.punzoni.length));
      expect(riletto.matrici, hasLength(originale.matrici.length));

      final v16 = riletto.matricePerId('sys_matrice_v16');
      expect(v16, isNotNull);
      expect(v16!.aperturaV, 16);
      expect(v16.angoloV, 85);
    });

    test("un collo d'oca conserva le misure della golla", () {
      final originale = Inventario(punzoni: [
        Punzone(
          id: 'mio_collo',
          nome: "Collo d'oca mio",
          angoloPunta: 88,
          raggioPunta: 1.2,
          altezza: 100,
          tipo: TipoPunzone.colloDoca,
          gollaProfondita: 18,
          gollaAltezza: 50,
        ),
      ]);
      final riletto = ArchivioJson.inventarioDaTesto(
          ArchivioJson.inventarioATesto(originale))!;
      final punzone = riletto.punzonePerId('mio_collo')!;

      expect(punzone.tipo, TipoPunzone.colloDoca);
      expect(punzone.gollaProfondita, 18);
      expect(punzone.gollaAltezza, 50);
      expect(punzone.eColloDoca, isTrue);
    });

    test('un testo illeggibile non fa esplodere nulla', () {
      expect(ArchivioJson.inventarioDaTesto(null), isNull);
      expect(ArchivioJson.inventarioDaTesto(''), isNull);
      expect(ArchivioJson.inventarioDaTesto('non è json'), isNull);
      expect(ArchivioJson.inventarioDaTesto('[1,2,3]'), isNull);
    });

    test('il ripristino rimette le voci mancanti senza toccare le mie', () {
      final mio = Punzone(
        id: 'mio_punzone',
        nome: 'Il mio coltello',
        angoloPunta: 88,
        raggioPunta: 1.0,
        altezza: 100,
      );
      final ridotto = Inventario(punzoni: [mio], matrici: const []);
      final ripristinato = ArchivioJson.conCatalogoRipristinato(ridotto);

      expect(ripristinato.punzonePerId('mio_punzone'), isNotNull);
      expect(ripristinato.punzonePerId('sys_punzone_88_r08'), isNotNull);
      expect(ripristinato.matricePerId('sys_matrice_v16'), isNotNull);
    });

    test('il ripristino non duplica quello che c\'è già', () {
      final completo = CatalogoStandard.inventario();
      final ripristinato = ArchivioJson.conCatalogoRipristinato(completo);
      expect(ripristinato.punzoni, hasLength(completo.punzoni.length));
      expect(ripristinato.matrici, hasLength(completo.matrici.length));
    });
  });

  group('Impostazioni e materiali', () {
    test('le impostazioni sopravvivono al salvataggio', () {
      const originali = Impostazioni(
        latoMinimo: ParametriLatoMinimo(coefficiente: 0.69),
        giocoMinimo: 1.0,
        decimaliLunghezza: 2,
        modalitaOfficina: true,
      );
      final rilette =
          ArchivioJson.impostazioniDaTesto(ArchivioJson.impostazioniATesto(originali))!;

      expect(rilette.latoMinimo.coefficiente, 0.69);
      expect(rilette.giocoMinimo, 1.0);
      expect(rilette.decimaliLunghezza, 2);
      expect(rilette.modalitaOfficina, isTrue);
    });

    test('un materiale tarato conserva la sua correzione', () {
      final tarato =
          TabellaMateriali.acciaioDolce.copiaCon(correzioneK: 1.15);
      final riletti =
          ArchivioJson.materialiDaTesto(ArchivioJson.materialiATesto([tarato]))!;

      expect(riletti.first.correzioneK, closeTo(1.15, 1e-9));
      expect(riletti.first.eTarato, isTrue);
    });
  });

  group("Modifica dell'inventario", () {
    test('aggiungere, sostituire e togliere', () {
      var inventario = Inventario.vuoto;
      final punzone = Punzone(
        id: 'p1',
        nome: 'Primo',
        angoloPunta: 88,
        raggioPunta: 0.8,
        altezza: 100,
      );

      inventario = inventario.conPunzone(punzone);
      expect(inventario.punzoni, hasLength(1));

      inventario = inventario.conPunzone(punzone.copiaCon(nome: 'Rinominato'));
      expect(inventario.punzoni, hasLength(1),
          reason: 'lo stesso id deve sostituire, non duplicare');
      expect(inventario.punzonePerId('p1')!.nome, 'Rinominato');

      inventario = inventario.senzaPunzone('p1');
      expect(inventario.punzoni, isEmpty);
    });

    test('le cave si ordinano per apertura', () {
      final inventario = CatalogoStandard.inventario();
      final aperture = [for (final m in inventario.matriciOrdinate) m.aperturaV];
      for (var i = 1; i < aperture.length; i++) {
        expect(aperture[i], greaterThanOrEqualTo(aperture[i - 1]));
      }
    });
  });

  group('Scelta della cava', () {
    test('la regola segue lo spessore', () {
      expect(RegolaMatrice.vConsigliata(2), 16);
      expect(RegolaMatrice.vConsigliata(1), 8);
      expect(RegolaMatrice.vConsigliata(5), 50);
      expect(RegolaMatrice.vConsigliata(9), 108);
    });

    test('propone la cava più vicina a quella consigliata', () {
      final inventario = CatalogoStandard.inventario();
      expect(
        RegolaMatrice.miglioreDisponibile(inventario, 2)!.aperturaV,
        16,
      );
      expect(
        RegolaMatrice.miglioreDisponibile(inventario, 1)!.aperturaV,
        8,
      );
    });

    test('senza cave adatte restituisce null invece di inventare', () {
      final inventario = Inventario(matrici: [
        Matrice(id: 'v4', nome: 'V4', aperturaV: 4),
      ]);
      expect(RegolaMatrice.miglioreDisponibile(inventario, 10), isNull);
    });

    test('una cava fuori regola viene segnalata', () {
      final stretta = Matrice(id: 'v8', nome: 'V8', aperturaV: 8);
      expect(RegolaMatrice.verifica(stretta, 3), isNotEmpty);

      final giusta = Matrice(id: 'v16', nome: 'V16', aperturaV: 16);
      expect(RegolaMatrice.verifica(giusta, 2), isEmpty);
    });
  });

  group('Formattazione italiana', () {
    test('virgola decimale e separatore di migliaia', () {
      expect(FormatoNumero.misura(196.0159, decimali: 1), '196,0');
      expect(FormatoNumero.mm(3.98, decimali: 2), '3,98 mm');
      expect(FormatoNumero.gradi(88), '88,0°');
      expect(FormatoNumero.misura(12345.6, decimali: 1), '12.345,6');
      expect(FormatoNumero.misura(-42.5, decimali: 1), '-42,5');
    });

    test('rilegge sia la virgola sia il punto', () {
      expect(FormatoNumero.leggi('196,0'), closeTo(196, 1e-9));
      expect(FormatoNumero.leggi('196.0'), closeTo(196, 1e-9));
      expect(FormatoNumero.leggi(' 2,5 '), closeTo(2.5, 1e-9));
      expect(FormatoNumero.leggi('abc'), isNull);
      expect(FormatoNumero.leggi(''), isNull);
    });
  });

  group('Il core non dipende da Flutter', () {
    test('nessun sorgente importa package:flutter', () {
      final cartella = Directory('lib');
      expect(cartella.existsSync(), isTrue);

      final colpevoli = <String>[];
      for (final file in cartella.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.readAsStringSync().contains('package:flutter')) {
          colpevoli.add(file.path);
        }
      }

      expect(colpevoli, isEmpty,
          reason: 'il core deve restare Dart puro per girare senza SDK Android');
    });
  });
}
