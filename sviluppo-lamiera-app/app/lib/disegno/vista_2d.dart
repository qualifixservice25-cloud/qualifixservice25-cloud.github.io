import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

/// Trasformazione fra i millimetri del modello e i pixel della tela.
///
/// Stessa idea del viewport del CAD Viewer: un solo posto in cui si converte,
/// così disegno e tocchi parlano sempre delle stesse coordinate. L'asse y del
/// modello punta in alto, quello della tela in basso: l'inversione avviene qui
/// e solo qui.
class Vista2D {
  final double scala;
  final Offset traslazione;

  const Vista2D({required this.scala, required this.traslazione});

  /// Inquadra [ingombro] dentro [tela] lasciando un margine.
  factory Vista2D.adattaA(
    Rettangolo ingombro,
    Size tela, {
    double margine = 20,
  }) {
    final larghezza = math.max(ingombro.larghezza, 1.0);
    final altezza = math.max(ingombro.altezza, 1.0);
    final disponibileX = math.max(tela.width - 2 * margine, 1.0);
    final disponibileY = math.max(tela.height - 2 * margine, 1.0);
    final scala = math.min(disponibileX / larghezza, disponibileY / altezza);

    final centro = ingombro.centro;
    return Vista2D(
      scala: scala,
      traslazione: Offset(
        tela.width / 2 - centro.x * scala,
        tela.height / 2 + centro.y * scala,
      ),
    );
  }

  Offset aPixel(Vec2 p) =>
      Offset(p.x * scala + traslazione.dx, -p.y * scala + traslazione.dy);

  Vec2 aModello(Offset p) => Vec2(
        (p.dx - traslazione.dx) / scala,
        -(p.dy - traslazione.dy) / scala,
      );

  /// Converte una lunghezza in millimetri nei pixel corrispondenti.
  double lunghezza(double mm) => mm * scala;

  Path percorso(List<Vec2> punti, {bool chiuso = false}) {
    final path = Path();
    if (punti.isEmpty) return path;
    path.moveTo(aPixel(punti.first).dx, aPixel(punti.first).dy);
    for (var i = 1; i < punti.length; i++) {
      final p = aPixel(punti[i]);
      path.lineTo(p.dx, p.dy);
    }
    if (chiuso) path.close();
    return path;
  }

  Path percorsoPoligono(Poligono poligono) =>
      percorso(poligono.vertici, chiuso: true);
}

/// I colori del disegno tecnico, coerenti fra tema chiaro e modalità officina.
class ColoriDisegno {
  final Color lamiera;
  final Color bordoLamiera;
  final Color utensile;
  final Color bordoUtensile;
  final Color quota;
  final Color testoQuota;
  final Color allarme;
  final Color lineaDiPiega;
  final Color sfondo;

  const ColoriDisegno({
    required this.lamiera,
    required this.bordoLamiera,
    required this.utensile,
    required this.bordoUtensile,
    required this.quota,
    required this.testoQuota,
    required this.allarme,
    required this.lineaDiPiega,
    required this.sfondo,
  });

  factory ColoriDisegno.da(ThemeData tema) {
    final scuro = tema.brightness == Brightness.dark;
    return ColoriDisegno(
      lamiera: scuro ? const Color(0xFF3E5A6E) : const Color(0xFFBFD4E4),
      bordoLamiera: scuro ? const Color(0xFF9FC6E0) : const Color(0xFF2C3E50),
      utensile: scuro ? const Color(0xFF2A343D) : const Color(0xFFE3E7EA),
      bordoUtensile: scuro ? const Color(0xFF6B7B88) : const Color(0xFF8A9BA8),
      quota: scuro ? const Color(0xFF8FA3B0) : const Color(0xFF7F8C8D),
      testoQuota: scuro ? const Color(0xFFD6E1E8) : const Color(0xFF2C3E50),
      allarme: const Color(0xFFE74C3C),
      lineaDiPiega: const Color(0xFFE67E22),
      sfondo: scuro ? const Color(0xFF0F1418) : Colors.white,
    );
  }
}
