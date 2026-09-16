import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sviluppo_lamiera/disegno/painter_profilo.dart';
import 'package:sviluppo_lamiera/disegno/vista_2d.dart';
import 'package:sviluppo_lamiera/disegno/zone_tocco.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

/// Il disegno è l'editor: se le zone toccabili non ci sono, non si modifica
/// niente. Si verificano direttamente sul painter, che è dove vengono prodotte.
void main() {
  List<ZonaTocco> zoneDi(ProfiloLamiera profilo, {Size misura = const Size(600, 400)}) {
    final inventario = CatalogoStandard.inventario();
    final sviluppo = CalcoloSviluppo.calcola(profilo, inventario);
    final geometria = CostruttoreGeometria.costruisci(
      profilo: profilo,
      trattiPiani: sviluppo.trattiPiani,
      pieghe: sviluppo.pieghe,
    );

    final zone = <ZonaTocco>[];
    final painter = PainterProfilo(
      geometria: geometria,
      profilo: profilo,
      quote: [for (final t in profilo.tratti) t.lunghezza],
      colori: ColoriDisegno.da(ThemeData.light()),
      zone: zone,
    );
    painter.paint(Canvas(PictureRecorder()), misura);
    return zone;
  }

  ProfiloLamiera profilo(List<double> quote, List<PiegaProfilo> pieghe) =>
      ProfiloLamiera(
        spessore: 2,
        idMatricePredefinita: 'sys_matrice_v16',
        tratti: [
          for (var i = 0; i < quote.length; i++)
            TrattoProfilo('ABCDE'[i], quote[i]),
        ],
        pieghe: pieghe,
      );

  test('una squadretta espone due quote, una piega e due «+»', () {
    final zone = zoneDi(profilo([100, 100], const [PiegaProfilo()]));

    expect(zone.where((z) => z.tipo == TipoZona.lato).length, 2);
    expect(zone.where((z) => z.tipo == TipoZona.piega).length, 1);
    expect(zone.where((z) => z.tipo == TipoZona.aggiungiInizio).length, 1);
    expect(zone.where((z) => z.tipo == TipoZona.aggiungiFine).length, 1);
  });

  test('gli indici puntano al tratto e alla piega giusti', () {
    final zone = zoneDi(profilo(
      [40, 90, 60],
      const [PiegaProfilo(), PiegaProfilo(angoloFormato: 120)],
    ));

    expect(
      zone.where((z) => z.tipo == TipoZona.lato).map((z) => z.indice).toList()
        ..sort(),
      [0, 1, 2],
    );
    expect(
      zone.where((z) => z.tipo == TipoZona.piega).map((z) => z.indice).toList()
        ..sort(),
      [0, 1],
    );
  });

  test('ogni bersaglio è grande almeno quanto un dito', () {
    final zone = zoneDi(profilo([100, 100], const [PiegaProfilo()]));
    for (final z in zone) {
      expect(z.area.width, greaterThanOrEqualTo(ZonaTocco.latoMinimo - 0.01),
          reason: '${z.tipo} troppo stretta');
      expect(z.area.height, greaterThanOrEqualTo(ZonaTocco.latoMinimo - 0.01),
          reason: '${z.tipo} troppo bassa');
    }
  });

  test('le zone stanno dentro il riquadro', () {
    const misura = Size(600, 400);
    final zone = zoneDi(profilo([100, 100], const [PiegaProfilo()]),
        misura: misura);
    for (final z in zone) {
      expect(z.area.center.dx, inInclusiveRange(0, misura.width),
          reason: '${z.tipo} fuori dal riquadro');
      expect(z.area.center.dy, inInclusiveRange(0, misura.height),
          reason: '${z.tipo} fuori dal riquadro');
    }
  });

  test('le zone si rifanno a ogni disegno, non si accumulano', () {
    final p = profilo([100, 100], const [PiegaProfilo()]);
    final inventario = CatalogoStandard.inventario();
    final sviluppo = CalcoloSviluppo.calcola(p, inventario);
    final geometria = CostruttoreGeometria.costruisci(
      profilo: p,
      trattiPiani: sviluppo.trattiPiani,
      pieghe: sviluppo.pieghe,
    );
    final zone = <ZonaTocco>[];
    final painter = PainterProfilo(
      geometria: geometria,
      profilo: p,
      quote: const [100, 100],
      colori: ColoriDisegno.da(ThemeData.light()),
      zone: zone,
    );

    painter.paint(Canvas(PictureRecorder()), const Size(600, 400));
    final dopoUno = zone.length;
    painter.paint(Canvas(PictureRecorder()), const Size(600, 400));
    expect(zone.length, dopoUno,
        reason: 'la lista va svuotata a ogni paint, altrimenti i vecchi '
            'bersagli restano attivi dove non c\'è più niente');
  });
}
