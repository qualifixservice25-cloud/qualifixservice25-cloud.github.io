import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';
import 'package:test/test.dart';

/// Le proprietà che devono valere sempre, non solo sui casi noti.
///
/// Sono le guardie che intercettano le regressioni silenziose: un errore di
/// segno o una costante assoluta infilata per sbaglio non cambia il caso di
/// riferimento, ma rompe queste.
void main() {
  group("Invarianza di scala: con V = 8·S la detrazione vale sempre 1,992·S", () {
    // Con V = 8·S il rapporto Ri/S è costante (1,264) per qualunque spessore,
    // quindi K è costante e la detrazione scala esattamente con lo spessore.
    // Qualsiasi costante assoluta che finisca nelle formule rompe questo test.
    const spessori = [0.5, 0.8, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0];

    for (final s in spessori) {
      test('S = $s mm', () {
        final r = CalcoloPiega.calcola(ParametriPiega(
          spessore: s,
          angoloFormato: 90,
          aperturaV: 8 * s,
          materiale: TabellaMateriali.acciaioDolce,
        ));
        expect(r.bdInSpessori, closeTo(1.9922, 1e-3),
            reason: 'BD/S deve essere costante con V = 8·S');
        expect(r.rapportoRaggioSpessore, closeTo(1.264, 1e-3));
      });
    }
  });

  group('Proprietà monotòne', () {
    ParametriPiega base({double angolo = 90, double v = 16}) => ParametriPiega(
          spessore: 2,
          angoloFormato: angolo,
          aperturaV: v,
          materiale: TabellaMateriali.acciaioDolce,
        );

    test('la detrazione cala man mano che l\'angolo si apre', () {
      const angoli = [30.0, 45.0, 60.0, 90.0, 120.0, 135.0, 160.0];
      var precedente = double.infinity;
      for (final a in angoli) {
        final bd = CalcoloPiega.calcola(base(angolo: a)).bd;
        expect(bd, lessThan(precedente),
            reason: 'BD a $a° dovrebbe essere minore che a un angolo più chiuso');
        precedente = bd;
      }
    });

    test("l'abbuono cresce con l'apertura della cava", () {
      var precedente = double.negativeInfinity;
      for (final v in const [8.0, 10.0, 12.0, 16.0, 20.0, 25.0]) {
        final ba = CalcoloPiega.calcola(base(v: v)).ba;
        expect(ba, greaterThan(precedente));
        precedente = ba;
      }
    });

    test('il raggio interno cresce in proporzione alla cava', () {
      final r8 = CalcoloPiega.calcola(base(v: 8)).raggioInterno;
      final r16 = CalcoloPiega.calcola(base(v: 16)).raggioInterno;
      expect(r16, closeTo(2 * r8, 1e-9));
    });

    test('a 180° non c\'è piega: abbuono, sporgenza e detrazione sono nulli', () {
      final r = CalcoloPiega.calcola(base(angolo: 180));
      expect(r.ba, closeTo(0, 1e-9));
      expect(r.ossb, closeTo(0, 1e-9));
      expect(r.bd, closeTo(0, 1e-9));
    });
  });

  group('Il fattore K resta nel suo intervallo fisico', () {
    test('K non esce mai da [0; 0,5] su tutto il dominio', () {
      for (var s = 0.3; s <= 12; s += 0.3) {
        for (var v = 4.0; v <= 120; v += 4) {
          for (final materiale in TabellaMateriali.standard) {
            final ri = CalcoloPiega.raggioInternoDaCava(v, materiale);
            final k = FattoreK.fattoreK(ri, s);
            expect(k, inInclusiveRange(0, FattoreK.massimo),
                reason: 'S=$s V=$v ${materiale.id}');
          }
        }
      }
    });

    test('attorno a Ri/S = 5 il DIN arriva al massimo K = 0,5', () {
      // La regola di officina dice «oltre cinque spessori di raggio l'asse
      // neutro sta in mezzo». La formula la riproduce quasi esattamente: a
      // Ri/S = 5 dà 0,49974, e tocca il massimo a Ri/S = 10^0,7 = 5,0119.
      // La differenza è mezzo millesimo di spessore: ininfluente in officina,
      // ma va scritta invece di arrotondarla via.
      expect(FattoreK.fattoreK(10, 2), closeTo(0.49974, 1e-5));
      expect(FattoreK.kDin6935(10, 2), closeTo(0.99949, 1e-5));

      // Dal punto di saturazione in poi resta fermo al massimo.
      expect(FattoreK.fattoreK(10.03, 2), closeTo(FattoreK.massimo, 1e-9));
      expect(FattoreK.fattoreK(40, 2), closeTo(FattoreK.massimo, 1e-9));
    });

    test('il fattore K cresce col rapporto raggio/spessore', () {
      var precedente = double.negativeInfinity;
      for (final rapporto in const [0.5, 1.0, 1.5, 2.0, 3.0, 4.0]) {
        final k = FattoreK.fattoreK(rapporto * 2, 2);
        expect(k, greaterThan(precedente));
        precedente = k;
      }
    });
  });

  group('Coerenza fra materiali', () {
    test('l\'inox produce un raggio più largo dell\'acciaio dolce', () {
      final acciaio = CalcoloPiega.calcola(ParametriPiega(
        spessore: 2,
        angoloFormato: 90,
        aperturaV: 16,
        materiale: TabellaMateriali.acciaioDolce,
      ));
      final inox = CalcoloPiega.calcola(ParametriPiega(
        spessore: 2,
        angoloFormato: 90,
        aperturaV: 16,
        materiale: TabellaMateriali.inox304,
      ));
      final alluminio = CalcoloPiega.calcola(ParametriPiega(
        spessore: 2,
        angoloFormato: 90,
        aperturaV: 16,
        materiale: TabellaMateriali.alluminio5754,
      ));

      expect(inox.raggioInterno, greaterThan(acciaio.raggioInterno));
      expect(alluminio.raggioInterno, lessThan(acciaio.raggioInterno));
      // Un raggio più largo significa una detrazione più grande.
      expect(inox.bd, greaterThan(acciaio.bd));
      expect(alluminio.bd, lessThan(acciaio.bd));
    });
  });
}
