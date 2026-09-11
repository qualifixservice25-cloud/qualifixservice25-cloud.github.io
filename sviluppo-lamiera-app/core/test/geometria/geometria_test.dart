import 'dart:math' as math;

import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';
import 'package:test/test.dart';

void main() {
  group('Poligono', () {
    final quadrato = const Poligono([
      Vec2(0, 0),
      Vec2(10, 0),
      Vec2(10, 10),
      Vec2(0, 10),
    ]);

    test('appartenenza di un punto', () {
      expect(quadrato.contiene(const Vec2(5, 5)), isTrue);
      expect(quadrato.contiene(const Vec2(15, 5)), isFalse);
      expect(quadrato.contiene(const Vec2(-1, 5)), isFalse);
    });

    test('i vertici antiorari danno area positiva', () {
      expect(quadrato.areaConSegno, closeTo(100, 1e-9));
    });

    test('ingombro', () {
      final i = quadrato.ingombro;
      expect(i.larghezza, closeTo(10, 1e-9));
      expect(i.altezza, closeTo(10, 1e-9));
    });

    test('specchiare conserva il verso di percorrenza', () {
      expect(quadrato.specchiatoSuY.areaConSegno, closeTo(100, 1e-9));
    });
  });

  group('Intersezioni', () {
    test('segmenti che si incrociano', () {
      expect(
        segmentiSiIntersecano(const Vec2(0, 0), const Vec2(10, 10),
            const Vec2(0, 10), const Vec2(10, 0)),
        isTrue,
      );
    });

    test('segmenti paralleli non si incrociano', () {
      expect(
        segmentiSiIntersecano(const Vec2(0, 0), const Vec2(10, 0),
            const Vec2(0, 5), const Vec2(10, 5)),
        isFalse,
      );
    });

    test('segmenti che si toccano in un estremo', () {
      expect(
        segmentiSiIntersecano(const Vec2(0, 0), const Vec2(10, 0),
            const Vec2(10, 0), const Vec2(10, 10)),
        isTrue,
      );
    });

    test('distanza punto-segmento', () {
      expect(
        distanzaPuntoSegmento(
            const Vec2(5, 3), const Vec2(0, 0), const Vec2(10, 0)),
        closeTo(3, 1e-9),
      );
      // Oltre l'estremo si misura dall'estremo.
      expect(
        distanzaPuntoSegmento(
            const Vec2(15, 0), const Vec2(0, 0), const Vec2(10, 0)),
        closeTo(5, 1e-9),
      );
    });

    test('distanza fra segmenti', () {
      expect(
        distanzaSegmentoSegmento(const Vec2(0, 0), const Vec2(10, 0),
            const Vec2(0, 4), const Vec2(10, 4)),
        closeTo(4, 1e-9),
      );
    });
  });

  group('Sagome degli utensili', () {
    test('la profondità della cava segue apertura e angolo', () {
      // V16 a 85°: 8 / tan(42,5°) = 8,73 mm.
      expect(SagomaUtensile.profonditaCava(16, 85), closeTo(8.730, 0.005));
      // Una V a 90° è meno profonda a parità di apertura.
      expect(SagomaUtensile.profonditaCava(16, 90), closeTo(8.0, 1e-9));
    });

    test('il punzone ha la punta nell\'origine e il corpo in alto', () {
      final sagoma = SagomaUtensile.punzone(
        angoloPunta: 88,
        raggioPunta: 0.8,
        altezza: 120,
      );
      expect(sagoma.eValido, isTrue);
      final i = sagoma.ingombro;
      expect(i.minY, closeTo(0, 1e-6));
      expect(i.maxY, closeTo(120, 1e-6));
      // Poco sopra la punta si è dentro il materiale dell'utensile.
      expect(sagoma.contiene(const Vec2(0, 1.0)), isTrue);
      // Sotto la punta si è fuori.
      expect(sagoma.contiene(const Vec2(0, -1.0)), isFalse);
    });

    test("il collo d'oca genera una rientranza vera", () {
      final dritto = SagomaUtensile.punzone(
        angoloPunta: 88,
        raggioPunta: 0.8,
        altezza: 120,
        larghezzaCorpo: 40,
      );
      final collo = SagomaUtensile.punzone(
        angoloPunta: 88,
        raggioPunta: 0.8,
        altezza: 120,
        larghezzaCorpo: 40,
        gollaProfondita: 16,
        gollaAltezza: 45,
      );

      expect(collo.vertici.length, greaterThan(dritto.vertici.length));
      // La rientranza è concava: l'area del collo d'oca è minore.
      expect(collo.areaConSegno.abs(), lessThan(dritto.areaConSegno.abs()));
    });

    test('la cava ha le spalle sul piano zero e l\'apice in basso', () {
      final sagoma = SagomaUtensile.matriceAV(
        aperturaV: 16,
        angoloV: 85,
        raggioSpalla: 1.5,
        altezza: 60,
      );
      expect(sagoma.eValido, isTrue);
      expect(sagoma.ingombro.maxY, closeTo(0, 1e-6));
      // Il punto in mezzo alla V, appena sopra l'apice, è aria non materiale.
      expect(sagoma.contiene(const Vec2(0, -4)), isFalse);
      // Il corpo sotto l'apice invece è pieno.
      expect(sagoma.contiene(const Vec2(0, -20)), isTrue);
    });
  });

  group('Posizionamento del pezzo sulla cava', () {
    const raggioEsterno = 4.528;

    test('a lamiera piatta il pezzo appoggia sul piano delle spalle', () {
      expect(
        PosizionatorePezzo.quotaCentro(
          aperturaV: 16,
          angoloIncluso: 180,
          raggioEsterno: raggioEsterno,
        ),
        closeTo(raggioEsterno, 1e-9),
      );
      expect(
        PosizionatorePezzo.penetrazione(
          aperturaV: 16,
          angoloIncluso: 180,
          raggioEsterno: raggioEsterno,
        ),
        closeTo(0, 1e-9),
      );
    });

    test('a 90° il pezzo è sceso di 6,12 mm dentro la V16', () {
      expect(
        PosizionatorePezzo.penetrazione(
          aperturaV: 16,
          angoloIncluso: 90,
          raggioEsterno: raggioEsterno,
        ),
        closeTo(6.124, 0.01),
      );
    });

    test('con V16 a 85° il pezzo non tocca il fondo a 90°', () {
      final matrice = Matrice(
          id: 'v16', nome: 'V16', aperturaV: 16, angoloV: 85);
      expect(
        PosizionatorePezzo.vaInBattuta(
          matrice: matrice,
          angoloIncluso: 90,
          raggioEsterno: raggioEsterno,
        ),
        isFalse,
      );
    });

    test('la penetrazione cresce man mano che la piega si chiude', () {
      var precedente = double.negativeInfinity;
      for (final angolo in const [180.0, 150.0, 120.0, 90.0, 60.0]) {
        final p = PosizionatorePezzo.penetrazione(
          aperturaV: 16,
          angoloIncluso: angolo,
          raggioEsterno: raggioEsterno,
        );
        expect(p, greaterThan(precedente), reason: 'a $angolo°');
        precedente = p;
      }
    });

    test('la punta del punzone scende insieme al pezzo', () {
      final a180 = PosizionatorePezzo.quotaPuntaPunzone(
        aperturaV: 16,
        angoloIncluso: 180,
        raggioInterno: 2.528,
        raggioPunta: 0.8,
        spessore: 2,
      );
      final a90 = PosizionatorePezzo.quotaPuntaPunzone(
        aperturaV: 16,
        angoloIncluso: 90,
        raggioInterno: 2.528,
        raggioPunta: 0.8,
        spessore: 2,
      );
      expect(a180, closeTo(2.8, 1e-3));
      expect(a90, closeTo(-3.324, 0.01));
      expect(a90, lessThan(a180));
    });
  });

  group('Geometria del profilo formato', () {
    final inventario = CatalogoStandard.inventario();
    final profilo = ProfiloLamiera(
      spessore: 2,
      idMatricePredefinita: 'sys_matrice_v16',
      tratti: const [TrattoProfilo('A', 100), TrattoProfilo('B', 100)],
      pieghe: const [PiegaProfilo()],
    );
    final sviluppo = CalcoloSviluppo.calcola(profilo, inventario);

    test("l'area della sezione corrisponde a lunghezza per spessore", () {
      final g = CostruttoreGeometria.costruisci(
        profilo: profilo,
        trattiPiani: sviluppo.trattiPiani,
        pieghe: sviluppo.pieghe,
      );

      // Per una striscia di spessore costante l'area della sezione vale
      // spessore × lunghezza misurata sulla mezzeria.
      final raggioMezzeria = sviluppo.pieghe.first.raggioInterno + 1;
      final lunghezzaMezzeria = sviluppo.trattiPiani.reduce((a, b) => a + b) +
          (math.pi / 2) * raggioMezzeria;
      final atteso = 2 * lunghezzaMezzeria;

      expect(g.sezione.areaConSegno.abs(), closeTo(atteso, atteso * 0.005));
    });

    test('a pezzo piatto la sezione è un rettangolo lungo quanto lo sviluppo', () {
      final g = CostruttoreGeometria.costruisci(
        profilo: profilo,
        trattiPiani: sviluppo.trattiPiani,
        pieghe: sviluppo.pieghe,
        angoliCorrenti: const {0: 180},
      );
      expect(g.ingombro.altezza, closeTo(2, 1e-6));
      expect(g.ingombro.larghezza,
          closeTo(sviluppo.trattiPiani.reduce((a, b) => a + b), 1e-6));
    });

    test('posato sulla cava il pezzo è centrato e coi lembi in alto', () {
      final matrice = inventario.matricePerId('sys_matrice_v16')!;
      final posato = PosizionatorePezzo.posa(
        profilo: profilo,
        trattiPiani: sviluppo.trattiPiani,
        pieghe: sviluppo.pieghe,
        matrice: matrice,
        indicePiega: 0,
        giaPiegate: const {},
        angoloIncluso: 90,
      );

      // Simmetrico rispetto all'asse della cava.
      expect(posato.ingombro.centro.x, closeTo(0, 0.5));
      // Il fondo del pezzo è dentro la V, la parte alta sopra il piano.
      expect(posato.quotaMinima, lessThan(0));
      expect(posato.altezzaMassima, greaterThan(0));
      // E scende quanto dice la formula di penetrazione.
      expect(posato.quotaMinima, closeTo(-6.124, 0.1));
    });

    test('il ribaltamento specchia il pezzo senza deformarlo', () {
      final dritto = CostruttoreGeometria.costruisci(
        profilo: profilo,
        trattiPiani: sviluppo.trattiPiani,
        pieghe: sviluppo.pieghe,
      );
      final ribaltato = CostruttoreGeometria.costruisci(
        profilo: profilo,
        trattiPiani: sviluppo.trattiPiani,
        pieghe: sviluppo.pieghe,
        ribaltato: true,
      );

      expect(ribaltato.sezione.areaConSegno.abs(),
          closeTo(dritto.sezione.areaConSegno.abs(), 1e-6));
      expect(ribaltato.ingombro.larghezza,
          closeTo(dritto.ingombro.larghezza, 1e-6));
    });
  });
}
