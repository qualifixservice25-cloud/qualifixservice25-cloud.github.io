import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';
import 'package:test/test.dart';

/// I casi di riferimento del progetto, verificati contro la pratica di
/// officina. Se uno di questi si muove, il motore è rotto.
void main() {
  group('Caso di riferimento: S=2, V=16, acciaio dolce, 90°', () {
    final risultato = CalcoloPiega.calcola(ParametriPiega(
      spessore: 2,
      angoloFormato: 90,
      aperturaV: 16,
      materiale: TabellaMateriali.acciaioDolce,
    ));

    test('il raggio interno lo produce la cava', () {
      expect(risultato.raggioInterno, closeTo(2.528, 1e-3));
    });

    test('il fattore K viene dal DIN 6935', () {
      expect(risultato.fattoreK, closeTo(0.35044, 1e-4));
      expect(risultato.origineK, OrigineValore.din6935);
    });

    test('abbuono, sporgenza e detrazione', () {
      expect(risultato.ba, closeTo(5.0719, 1e-3));
      expect(risultato.ossb, closeTo(4.528, 1e-3));
      expect(risultato.bd, closeTo(3.9841, 1e-3));
    });

    test('la detrazione vale circa due spessori, come dice la regola', () {
      expect(risultato.bdInSpessori, closeTo(1.992, 1e-3));
    });

    test('la catena di derivazione è completa e visibile', () {
      expect(risultato.catena.length, greaterThanOrEqualTo(6));
      expect(
        risultato.catena.map((p) => p.etichetta),
        containsAll(<String>[
          'Raggio interno dalla cava',
          'Rapporto raggio/spessore',
          'Fattore K',
          'Abbuono (BA)',
          'Sporgenza esterna (OSSB)',
          'Detrazione (BD)',
        ]),
      );
    });
  });

  test('S=1, V=8, acciaio dolce, 90° → BD ≈ 1,992', () {
    final r = CalcoloPiega.calcola(ParametriPiega(
      spessore: 1,
      angoloFormato: 90,
      aperturaV: 8,
      materiale: TabellaMateriali.acciaioDolce,
    ));
    expect(r.bd, closeTo(1.992, 1e-3));
  });

  test('squadretta 100×100 con quote esterne → sviluppo ≈ 196,0 mm', () {
    final inventario = CatalogoStandard.inventario();
    final profilo = ProfiloLamiera(
      spessore: 2,
      idMatricePredefinita: 'sys_matrice_v16',
      tratti: const [TrattoProfilo('A', 100), TrattoProfilo('B', 100)],
      pieghe: const [PiegaProfilo()],
    );

    final sviluppo = CalcoloSviluppo.calcola(profilo, inventario);

    expect(sviluppo.eAttendibile, isTrue,
        reason: sviluppo.avvertimenti.join('\n'));
    expect(sviluppo.lunghezzaTotale, closeTo(196.0159, 0.05));
  });

  test('la linea di piega cade in mezzo su un pezzo simmetrico', () {
    final inventario = CatalogoStandard.inventario();
    final profilo = ProfiloLamiera(
      spessore: 2,
      idMatricePredefinita: 'sys_matrice_v16',
      tratti: const [TrattoProfilo('A', 100), TrattoProfilo('B', 100)],
      pieghe: const [PiegaProfilo()],
    );

    final sviluppo = CalcoloSviluppo.calcola(profilo, inventario);
    expect(sviluppo.posizioniLineeDiPiega, hasLength(1));
    expect(
      sviluppo.posizioniLineeDiPiega.first,
      closeTo(sviluppo.lunghezzaTotale / 2, 1e-6),
    );
  });

  test('lato minimo con V16 → 10,4 mm', () {
    final matrice = Matrice(id: 'v16', nome: 'V16', aperturaV: 16);
    final minimo = LatoMinimo.calcola(
      matrice: matrice,
      angoloFormato: 90,
      spessore: 2,
    );
    expect(minimo, closeTo(10.4, 1e-6));
  });

  test('la taratura inversa ritrova il fattore K di partenza', () {
    final k = CalibrazioneK.kDaDetrazione(
      bdMisurato: 3.9841,
      angoloRotazione: 90,
      raggioInterno: 2.528,
      spessore: 2,
    );
    expect(k, isNotNull);
    expect(k!, closeTo(0.35044, 1e-3));
  });
}
