import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';
import 'package:test/test.dart';

/// Ingressi storti, misure impossibili, casi limite.
///
/// La regola del progetto: o esce un numero finito, o esce un avvertimento
/// bloccante. Mai un NaN travestito da misura.
void main() {
  final inventario = CatalogoStandard.inventario();

  group('Ingressi degeneri sulla singola piega', () {
    test('spessore nullo viene rifiutato, non calcolato', () {
      final r = CalcoloPiega.calcola(ParametriPiega(
        spessore: 0,
        angoloFormato: 90,
        aperturaV: 16,
        materiale: TabellaMateriali.acciaioDolce,
      ));
      expect(r.avvertimenti.haErrori, isTrue);
    });

    test('angolo fuori intervallo viene segnalato', () {
      for (final angolo in const [-10.0, 0.0, 200.0]) {
        final r = CalcoloPiega.calcola(ParametriPiega(
          spessore: 2,
          angoloFormato: angolo,
          aperturaV: 16,
          materiale: TabellaMateriali.acciaioDolce,
        ));
        expect(r.avvertimenti.haErrori, isTrue, reason: 'angolo $angolo');
      }
    });

    test('angolo molto chiuso resta finito e avvisa', () {
      final r = CalcoloPiega.calcola(ParametriPiega(
        spessore: 2,
        angoloFormato: 5,
        aperturaV: 16,
        materiale: TabellaMateriali.acciaioDolce,
      ));
      expect(r.bd.isFinite, isTrue);
      expect(r.ba.isFinite, isTrue);
      expect(
        r.avvertimenti
            .any((a) => a.codice == CodiceAvvertimento.angoloFuoriRegime),
        isTrue,
      );
    });

    test('cava troppo stretta per lo spessore viene segnalata', () {
      final r = CalcoloPiega.calcola(ParametriPiega(
        spessore: 4,
        angoloFormato: 90,
        aperturaV: 8,
        materiale: TabellaMateriali.acciaioDolce,
      ));
      expect(
        r.avvertimenti
            .any((a) => a.codice == CodiceAvvertimento.cavaTroppoStretta),
        isTrue,
      );
    });

    test('raggio sotto il minimo del materiale avvisa della cricca', () {
      final r = CalcoloPiega.calcola(ParametriPiega(
        spessore: 3,
        angoloFormato: 90,
        aperturaV: 18,
        materiale: TabellaMateriali.alluminio6082,
      ));
      expect(
        r.avvertimenti
            .any((a) => a.codice == CodiceAvvertimento.raggioSuSpessoreBasso),
        isTrue,
      );
    });
  });

  group('Mai un NaN senza un errore che lo spieghi', () {
    test('griglia larga di ingressi sulla piega', () {
      for (var s = 0.2; s <= 12; s += 0.6) {
        for (var v = 3.0; v <= 120; v += 7) {
          for (var angolo = 1.0; angolo <= 180; angolo += 17) {
            for (final materiale in TabellaMateriali.standard) {
              final r = CalcoloPiega.calcola(ParametriPiega(
                spessore: s,
                angoloFormato: angolo,
                aperturaV: v,
                materiale: materiale,
              ));
              final finito = r.ba.isFinite &&
                  r.ossb.isFinite &&
                  r.bd.isFinite &&
                  r.raggioInterno.isFinite &&
                  r.fattoreK.isFinite;
              expect(
                finito || r.avvertimenti.haErrori,
                isTrue,
                reason: 'S=$s V=$v α=$angolo ${materiale.id} ha prodotto un '
                    'valore non finito senza segnalarlo',
              );
            }
          }
        }
      }
    });

    test('griglia di ingressi sullo sviluppo', () {
      for (var s = 0.5; s <= 8; s += 1.5) {
        for (final cava in const [
          'sys_matrice_v6',
          'sys_matrice_v16',
          'sys_matrice_v40',
        ]) {
          for (final lato in const [3.0, 12.0, 80.0, 500.0]) {
            final profilo = ProfiloLamiera(
              spessore: s,
              idMatricePredefinita: cava,
              tratti: [
                TrattoProfilo('A', lato),
                TrattoProfilo('B', lato),
                TrattoProfilo('C', lato),
              ],
              pieghe: const [PiegaProfilo(), PiegaProfilo(angoloFormato: 45)],
            );
            final r = CalcoloSviluppo.calcola(profilo, inventario);
            expect(
              r.lunghezzaTotale.isFinite || r.avvertimenti.haErrori,
              isTrue,
              reason: 'S=$s $cava lato=$lato',
            );
            if (r.eAttendibile) {
              expect(r.lunghezzaTotale, greaterThan(0));
            }
          }
        }
      }
    });

    test('la formattazione non mostra mai un NaN', () {
      expect(FormatoNumero.mm(double.nan), '—');
      expect(FormatoNumero.mm(double.infinity), '—');
      expect(FormatoNumero.gradi(double.nan), '—');
      expect(FormatoNumero.fattore(double.negativeInfinity), '—');
    });
  });

  group('Struttura del profilo', () {
    test('una catena incoerente viene rifiutata', () {
      const profilo = ProfiloLamiera(
        spessore: 2,
        idMatricePredefinita: 'sys_matrice_v16',
        tratti: [TrattoProfilo('A', 100), TrattoProfilo('B', 100)],
        pieghe: [PiegaProfilo(), PiegaProfilo()],
      );
      expect(profilo.haStrutturaValida, isFalse);
      expect(profilo.valida(inventario).haErrori, isTrue);
    });

    test('togliere un tratto rinumera le etichette', () {
      var profilo = ProfiloLamiera.esempio()
          .conTrattoAggiunto()
          .conTrattoAggiunto();
      expect(profilo.tratti.map((t) => t.etichetta), ['A', 'B', 'C', 'D']);

      profilo = profilo.senzaTratto(1);
      expect(profilo.tratti.map((t) => t.etichetta), ['A', 'B', 'C']);
      expect(profilo.haStrutturaValida, isTrue);
    });

    test('un profilo a due tratti non si può ridurre oltre', () {
      final profilo = ProfiloLamiera.esempio();
      expect(profilo.senzaTratto(0).tratti, hasLength(2));
    });
  });

  group('Taratura', () {
    test('una misura impossibile non produce un fattore inventato', () {
      expect(
        CalibrazioneK.kDaDetrazione(
          bdMisurato: 500,
          angoloRotazione: 90,
          raggioInterno: 2.528,
          spessore: 2,
        ),
        isNull,
      );
    });

    test('la taratura su un profilo ritrova il moltiplicatore usato', () {
      final profilo = ProfiloLamiera(
        spessore: 2,
        idMatricePredefinita: 'sys_matrice_v16',
        tratti: const [TrattoProfilo('A', 100), TrattoProfilo('B', 100)],
        pieghe: const [PiegaProfilo()],
      );

      // Si finge che la macchina reale dia lo sviluppo di un K corretto a 1,2.
      final finto = profilo.copiaCon(
        materiale: profilo.materiale.copiaCon(correzioneK: 1.2),
      );
      final misurato =
          CalcoloSviluppo.calcola(finto, inventario).lunghezzaTotale;

      final correzione = CalibrazioneK.correzioneDaSviluppoMisurato(
        profilo: profilo,
        inventario: inventario,
        sviluppoMisurato: misurato,
      );

      expect(correzione, isNotNull);
      expect(correzione!, closeTo(1.2, 1e-2));
    });

    test('uno sviluppo fuori scala non trova soluzione', () {
      final profilo = ProfiloLamiera(
        spessore: 2,
        idMatricePredefinita: 'sys_matrice_v16',
        tratti: const [TrattoProfilo('A', 100), TrattoProfilo('B', 100)],
        pieghe: const [PiegaProfilo()],
      );
      expect(
        CalibrazioneK.correzioneDaSviluppoMisurato(
          profilo: profilo,
          inventario: inventario,
          sviluppoMisurato: 50,
        ),
        isNull,
      );
    });
  });
}
