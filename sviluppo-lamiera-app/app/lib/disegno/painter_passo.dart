import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import 'vista_2d.dart';

/// Disegna un passo di piega come lo si vede stando di lato alla macchina:
/// cava sotto, coltello sopra, pezzo in mezzo nella posizione che ha davvero a
/// quel punto della corsa.
class PainterPassoSequenza extends CustomPainter {
  final GeometriaProfilo pezzo;
  final Poligono sagomaMatrice;
  final Poligono sagomaPunzone;
  final Vec2? puntoCritico;
  final ColoriDisegno colori;

  PainterPassoSequenza({
    required this.pezzo,
    required this.sagomaMatrice,
    required this.sagomaPunzone,
    required this.colori,
    this.puntoCritico,
  });

  @override
  void paint(Canvas tela, Size dimensione) {
    final ingombro = pezzo.ingombro
        .unito(sagomaMatrice.ingombro)
        .unito(sagomaPunzone.ingombro)
        .espanso(6);
    final vista = Vista2D.adattaA(ingombro, dimensione, margine: 12);

    final riempimentoUtensile = Paint()..color = colori.utensile;
    final bordoUtensile = Paint()
      ..color = colori.bordoUtensile
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // --- cava --------------------------------------------------------------
    final matrice = vista.percorsoPoligono(sagomaMatrice);
    tela.drawPath(matrice, riempimentoUtensile);
    tela.drawPath(matrice, bordoUtensile);

    // --- coltello ----------------------------------------------------------
    final punzone = vista.percorsoPoligono(sagomaPunzone);
    tela.drawPath(punzone, riempimentoUtensile);
    tela.drawPath(punzone, bordoUtensile);

    // --- pezzo -------------------------------------------------------------
    final lamiera = vista.percorsoPoligono(pezzo.sezione);
    tela.drawPath(lamiera, Paint()..color = colori.lamiera);
    tela.drawPath(
      lamiera,
      Paint()
        ..color = colori.bordoLamiera
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // --- asse della cava ---------------------------------------------------
    final asse = vista.aPixel(const Vec2(0, 0));
    tela.drawLine(
      Offset(asse.dx, 0),
      Offset(asse.dx, dimensione.height),
      Paint()
        ..color = colori.quota.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );

    // --- il punto che tocca -------------------------------------------------
    if (puntoCritico != null) {
      final p = vista.aPixel(puntoCritico!);
      tela.drawCircle(p, 7, Paint()..color = colori.allarme.withValues(alpha: 0.3));
      tela.drawCircle(
        p,
        7,
        Paint()
          ..color = colori.allarme
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  @override
  bool shouldRepaint(PainterPassoSequenza vecchio) =>
      vecchio.pezzo != pezzo ||
      vecchio.sagomaPunzone != sagomaPunzone ||
      vecchio.sagomaMatrice != sagomaMatrice ||
      vecchio.puntoCritico != puntoCritico ||
      vecchio.colori != colori;
}

/// Disegna la sagoma di un utensile da sola, per l'anteprima nella scheda
/// dell'inventario: mentre si digitano le misure si vede che forma esce.
class PainterUtensile extends CustomPainter {
  final Poligono sagoma;
  final ColoriDisegno colori;

  PainterUtensile({required this.sagoma, required this.colori});

  @override
  void paint(Canvas tela, Size dimensione) {
    if (!sagoma.eValido) return;
    final vista =
        Vista2D.adattaA(sagoma.ingombro.espanso(2), dimensione, margine: 8);
    final percorso = vista.percorsoPoligono(sagoma);
    tela.drawPath(percorso, Paint()..color = colori.utensile);
    tela.drawPath(
      percorso,
      Paint()
        ..color = colori.bordoUtensile
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(PainterUtensile vecchio) =>
      vecchio.sagoma != sagoma || vecchio.colori != colori;
}
