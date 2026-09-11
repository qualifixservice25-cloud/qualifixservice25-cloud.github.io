import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import 'vista_2d.dart';

/// Disegna la sezione del pezzo con le quote dei tratti.
class PainterProfilo extends CustomPainter {
  final GeometriaProfilo geometria;
  final ProfiloLamiera profilo;
  final RisultatoSviluppo sviluppo;
  final ColoriDisegno colori;
  final bool mostraQuote;

  PainterProfilo({
    required this.geometria,
    required this.profilo,
    required this.sviluppo,
    required this.colori,
    this.mostraQuote = true,
  });

  @override
  void paint(Canvas tela, Size dimensione) {
    if (geometria.mezzeria.length < 2) return;

    final ingombro = geometria.ingombro;
    final vista = Vista2D.adattaA(
      Rettangolo(
        ingombro.minX,
        ingombro.minY,
        ingombro.maxX,
        ingombro.maxY,
      ).espanso(mostraQuote ? ingombro.larghezza * 0.12 + 6 : 4),
      dimensione,
    );

    // --- la lamiera --------------------------------------------------------
    final corpo = vista.percorsoPoligono(geometria.sezione);
    tela.drawPath(corpo, Paint()..color = colori.lamiera);
    tela.drawPath(
      corpo,
      Paint()
        ..color = colori.bordoLamiera
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // --- le linee di piega -------------------------------------------------
    for (final arco in geometria.archi) {
      if (arco.rotazione.abs() < 1e-9) continue;
      final medio = geometria
          .mezzeria[(arco.indiceInizio + arco.indiceFine) ~/ 2];
      tela.drawCircle(
        vista.aPixel(medio),
        4,
        Paint()..color = colori.lineaDiPiega,
      );
      _etichetta(
        tela,
        vista.aPixel(medio) + const Offset(8, -20),
        '${arco.indicePiega + 1}',
        colori.lineaDiPiega,
        grassetto: true,
      );
    }

    if (!mostraQuote) return;

    // --- le quote dei tratti ----------------------------------------------
    var indice = 0;
    for (final arco in [...geometria.archi, null]) {
      final inizio = indice == 0 ? 0 : geometria.archi[indice - 1].indiceFine;
      final fine = arco?.indiceInizio ?? geometria.mezzeria.length - 1;
      if (fine <= inizio) {
        indice++;
        continue;
      }

      final a = geometria.mezzeria[inizio];
      final b = geometria.mezzeria[fine];
      final centro = (a + b) / 2;
      final etichetta = indice < profilo.tratti.length
          ? profilo.tratti[indice].etichetta
          : '';
      final quota = indice < sviluppo.righe.length
          ? sviluppo.righe[indice].quotaInserita
          : 0.0;

      _etichetta(
        tela,
        vista.aPixel(centro),
        '$etichetta ${FormatoNumero.misura(quota)}',
        colori.testoQuota,
        centrato: true,
        sfondo: colori.sfondo,
      );
      indice++;
    }
  }

  void _etichetta(
    Canvas tela,
    Offset posizione,
    String testo,
    Color colore, {
    bool centrato = false,
    bool grassetto = false,
    Color? sfondo,
  }) {
    final pittore = TextPainter(
      text: TextSpan(
        text: testo,
        style: TextStyle(
          color: colore,
          fontSize: 13,
          fontWeight: grassetto ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final origine = centrato
        ? posizione - Offset(pittore.width / 2, pittore.height / 2)
        : posizione;

    if (sfondo != null) {
      tela.drawRect(
        Rect.fromLTWH(
          origine.dx - 3,
          origine.dy - 1,
          pittore.width + 6,
          pittore.height + 2,
        ),
        Paint()..color = sfondo.withValues(alpha: 0.85),
      );
    }
    pittore.paint(tela, origine);
  }

  @override
  bool shouldRepaint(PainterProfilo vecchio) =>
      vecchio.geometria != geometria ||
      vecchio.sviluppo != sviluppo ||
      vecchio.colori != colori ||
      vecchio.mostraQuote != mostraQuote;
}

/// Disegna lo sviluppo disteso con le linee di piega quotate.
class PainterSviluppo extends CustomPainter {
  final RisultatoSviluppo sviluppo;
  final double spessore;
  final ColoriDisegno colori;

  PainterSviluppo({
    required this.sviluppo,
    required this.spessore,
    required this.colori,
  });

  @override
  void paint(Canvas tela, Size dimensione) {
    final lunghezza = sviluppo.lunghezzaTotale;
    if (!lunghezza.isFinite || lunghezza <= 0) return;

    const altezzaBarra = 46.0;
    final margine = dimensione.width * 0.06;
    final disponibile = dimensione.width - 2 * margine;
    final scala = disponibile / lunghezza;
    final cima = (dimensione.height - altezzaBarra) / 2;

    final barra = Rect.fromLTWH(margine, cima, disponibile, altezzaBarra);

    tela.drawRRect(
      RRect.fromRectAndRadius(barra, const Radius.circular(4)),
      Paint()..color = colori.lamiera,
    );
    tela.drawRRect(
      RRect.fromRectAndRadius(barra, const Radius.circular(4)),
      Paint()
        ..color = colori.bordoLamiera
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Le righe che si tracciano davvero sul pezzo.
    for (var i = 0; i < sviluppo.posizioniLineeDiPiega.length; i++) {
      final x = margine + sviluppo.posizioniLineeDiPiega[i] * scala;
      tela.drawLine(
        Offset(x, cima - 10),
        Offset(x, cima + altezzaBarra + 10),
        Paint()
          ..color = colori.lineaDiPiega
          ..strokeWidth = 2,
      );
      _testo(
        tela,
        Offset(x, cima + altezzaBarra + 14),
        FormatoNumero.misura(sviluppo.posizioniLineeDiPiega[i]),
        colori.lineaDiPiega,
        centrato: true,
      );
      _testo(
        tela,
        Offset(x, cima - 28),
        '${i + 1}',
        colori.lineaDiPiega,
        centrato: true,
        grassetto: true,
      );
    }

    _testo(
      tela,
      Offset(dimensione.width / 2, cima + altezzaBarra / 2 - 8),
      '${FormatoNumero.mm(lunghezza)} × spessore ${FormatoNumero.misura(spessore)}',
      colori.testoQuota,
      centrato: true,
      grassetto: true,
    );
  }

  void _testo(
    Canvas tela,
    Offset posizione,
    String testo,
    Color colore, {
    bool centrato = false,
    bool grassetto = false,
  }) {
    final pittore = TextPainter(
      text: TextSpan(
        text: testo,
        style: TextStyle(
          color: colore,
          fontSize: 12.5,
          fontWeight: grassetto ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pittore.paint(
      tela,
      centrato ? posizione - Offset(pittore.width / 2, 0) : posizione,
    );
  }

  @override
  bool shouldRepaint(PainterSviluppo vecchio) =>
      vecchio.sviluppo != sviluppo ||
      vecchio.spessore != spessore ||
      vecchio.colori != colori;
}
