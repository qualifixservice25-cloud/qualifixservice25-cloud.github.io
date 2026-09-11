import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';
import 'package:test/test.dart';

ProfiloLamiera _profilo({
  required List<double> quote,
  required List<PiegaProfilo> pieghe,
  QuotaturaProfilo quotatura = QuotaturaProfilo.esterna,
  double spessore = 2,
  String cava = 'sys_matrice_v16',
}) {
  const lettere = 'ABCDEFGH';
  return ProfiloLamiera(
    spessore: spessore,
    quotatura: quotatura,
    idMatricePredefinita: cava,
    tratti: [
      for (var i = 0; i < quote.length; i++)
        TrattoProfilo(lettere[i], quote[i]),
    ],
    pieghe: pieghe,
  );
}

void main() {
  final inventario = CatalogoStandard.inventario();

  group('Andata e ritorno fra quote esterne e quote interne', () {
    test('lo stesso pezzo fisico dà lo stesso sviluppo nei due modi', () {
      // Identità algebrica: Σesterne − ΣBD ≡ Σtratti piani + ΣBA.
      // Incrocia BD contro BA e OSSB in un colpo solo.
      final conEsterne = _profilo(
        quote: [60, 120, 40],
        pieghe: const [PiegaProfilo(), PiegaProfilo(angoloFormato: 120)],
      );
      final risultatoEsterne =
          CalcoloSviluppo.calcola(conEsterne, inventario);
      expect(risultatoEsterne.eAttendibile, isTrue);

      final conInterne = _profilo(
        quote: risultatoEsterne.trattiPiani,
        pieghe: const [PiegaProfilo(), PiegaProfilo(angoloFormato: 120)],
        quotatura: QuotaturaProfilo.interna,
      );
      final risultatoInterne =
          CalcoloSviluppo.calcola(conInterne, inventario);

      expect(
        risultatoInterne.lunghezzaTotale,
        closeTo(risultatoEsterne.lunghezzaTotale, 1e-9),
      );
    });

    test('le due formule dello sviluppo coincidono', () {
      final profilo = _profilo(
        quote: [50, 100, 50],
        pieghe: const [PiegaProfilo(), PiegaProfilo()],
      );
      final r = CalcoloSviluppo.calcola(profilo, inventario);

      final daEsterne = CalcoloSviluppo.daQuoteEsterne(
        [for (final riga in r.righe) riga.quotaInserita],
        r.pieghe,
      );
      final daInterne = CalcoloSviluppo.daQuoteInterne(
        r.trattiPiani,
        r.pieghe,
      );

      expect(daEsterne, closeTo(daInterne, 1e-9));
      expect(r.lunghezzaTotale, closeTo(daEsterne, 1e-9));
    });

    test('convertire avanti e indietro riporta ai numeri di partenza', () {
      final profilo = _profilo(
        quote: [60, 120, 40],
        pieghe: const [PiegaProfilo(), PiegaProfilo(angoloFormato: 135)],
      );
      final r = CalcoloSviluppo.calcola(profilo, inventario);
      final esterne = [for (final riga in r.righe) riga.quotaInserita];

      final interne = CalcoloSviluppo.esterneAInterne(esterne, r.pieghe);
      final ritorno = CalcoloSviluppo.interneAEsterne(interne, r.pieghe);

      for (var i = 0; i < esterne.length; i++) {
        expect(ritorno[i], closeTo(esterne[i], 1e-9));
      }
    });
  });

  group('Pezzi reali', () {
    test('profilo a U 50-100-50 → 192,03 mm', () {
      final profilo = _profilo(
        quote: [50, 100, 50],
        pieghe: const [PiegaProfilo(), PiegaProfilo()],
      );
      final r = CalcoloSviluppo.calcola(profilo, inventario);
      expect(r.eAttendibile, isTrue, reason: r.avvertimenti.join('\n'));
      expect(r.lunghezzaTotale, closeTo(192.032, 0.05));
      // Controprova a mano: 200 − 2 × 3,984.
      expect(r.lunghezzaTotale,
          closeTo(200 - 2 * r.pieghe.first.bd, 1e-9));
    });

    test('il verso della piega non cambia lo sviluppo', () {
      // Una U e una Z con gli stessi lati si sviluppano uguale: la lunghezza
      // non sa da che parte gira la lamiera.
      final aU = _profilo(
        quote: [50, 100, 50],
        pieghe: const [PiegaProfilo(), PiegaProfilo()],
      );
      final aZ = _profilo(
        quote: [50, 100, 50],
        pieghe: const [
          PiegaProfilo(),
          PiegaProfilo(verso: VersoPiega.giu),
        ],
      );

      expect(
        CalcoloSviluppo.calcola(aZ, inventario).lunghezzaTotale,
        closeTo(CalcoloSviluppo.calcola(aU, inventario).lunghezzaTotale, 1e-9),
      );
    });

    test('scatola aperta a quattro pieghe', () {
      final profilo = _profilo(
        quote: [30, 80, 120, 80, 30],
        pieghe: const [
          PiegaProfilo(),
          PiegaProfilo(),
          PiegaProfilo(),
          PiegaProfilo(),
        ],
      );
      final r = CalcoloSviluppo.calcola(profilo, inventario);
      expect(r.eAttendibile, isTrue, reason: r.avvertimenti.join('\n'));
      expect(r.lunghezzaTotale, closeTo(340 - 4 * r.pieghe.first.bd, 1e-9));
      expect(r.posizioniLineeDiPiega, hasLength(4));
      // Le linee di piega sono in ordine crescente lungo lo sviluppo.
      for (var i = 1; i < r.posizioniLineeDiPiega.length; i++) {
        expect(r.posizioniLineeDiPiega[i],
            greaterThan(r.posizioniLineeDiPiega[i - 1]));
      }
      // E stanno tutte dentro il pezzo.
      expect(r.posizioniLineeDiPiega.last, lessThan(r.lunghezzaTotale));
      expect(r.posizioniLineeDiPiega.first, greaterThan(0));
    });

    test('somma dei tratti piani più abbuoni uguale al totale', () {
      final profilo = _profilo(
        quote: [40, 90, 60],
        pieghe: const [PiegaProfilo(angoloFormato: 60), PiegaProfilo()],
      );
      final r = CalcoloSviluppo.calcola(profilo, inventario);
      var somma = 0.0;
      for (final t in r.trattiPiani) {
        somma += t;
      }
      expect(r.lunghezzaTotale, closeTo(somma + r.sommaAbbuoni, 1e-9));
    });
  });

  group('Rifiuti espliciti invece di numeri inventati', () {
    test('senza cava selezionata il risultato non è attendibile', () {
      final profilo = ProfiloLamiera(
        spessore: 2,
        tratti: const [TrattoProfilo('A', 100), TrattoProfilo('B', 100)],
        pieghe: const [PiegaProfilo()],
      );
      final r = CalcoloSviluppo.calcola(profilo, inventario);

      expect(r.eAttendibile, isFalse);
      expect(r.lunghezzaTotale.isFinite, isFalse);
      expect(
        r.avvertimenti.any(
            (a) => a.codice == CodiceAvvertimento.nessunaCavaAdatta),
        isTrue,
      );
    });

    test('un tratto più corto delle sporgenze viene bloccato', () {
      final profilo = _profilo(
        quote: [100, 5, 100],
        pieghe: const [PiegaProfilo(), PiegaProfilo()],
      );
      final r = CalcoloSviluppo.calcola(profilo, inventario);

      expect(r.eAttendibile, isFalse);
      expect(
        r.avvertimenti.any(
            (a) => a.codice == CodiceAvvertimento.flangiaMinoreDiSetback),
        isTrue,
      );
    });
  });
}
