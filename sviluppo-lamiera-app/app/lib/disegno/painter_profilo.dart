import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import 'vista_2d.dart';
import 'zone_tocco.dart';

/// Disegna la sezione del pezzo e, mentre disegna, registra dove ha messo le
/// etichette in [zone], così il widget può capire cosa è stato toccato.
///
/// Le quote e gli angoli non sono decorazioni: sono i comandi. Si tocca il
/// numero e si cambia il numero.
class PainterProfilo extends CustomPainter {
  final GeometriaProfilo geometria;
  final ProfiloLamiera profilo;

  /// Quote da mostrare sui tratti, nell'ordine. Sono quelle inserite
  /// dall'operatore, non quelle distese.
  final List<double> quote;

  final ColoriDisegno colori;

  /// Riempita a ogni `paint`. Il widget la interroga al tocco.
  final List<ZonaTocco> zone;

  /// Mostra i pulsanti «+» alle estremità.
  final bool modificabile;

  PainterProfilo({
    required this.geometria,
    required this.profilo,
    required this.quote,
    required this.colori,
    required this.zone,
    this.modificabile = true,
  });

  @override
  void paint(Canvas tela, Size dimensione) {
    zone.clear();
    if (geometria.mezzeria.length < 2) return;

    final ingombro = geometria.ingombro;
    // Quanto basta perché le etichette esterne non finiscano tagliate, senza
    // rimpicciolire il pezzo più del necessario: il riquadro è grande apposta.
    final margine = math.max(ingombro.larghezza, ingombro.altezza) * 0.10 + 5;
    final vista = Vista2D.adattaA(
      Rettangolo(ingombro.minX, ingombro.minY, ingombro.maxX, ingombro.maxY)
          .espanso(margine),
      dimensione,
      margine: 22,
    );
    final centro = ingombro.centro;

    // --- la lamiera --------------------------------------------------------
    final corpo = vista.percorsoPoligono(geometria.sezione);
    tela.drawPath(corpo, Paint()..color = colori.lamiera);
    tela.drawPath(
      corpo,
      Paint()
        ..color = colori.bordoLamiera
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // --- quote dei tratti --------------------------------------------------
    final estremi = _estremiTratti();
    for (var i = 0; i < estremi.length; i++) {
      final (inizio, fine) = estremi[i];
      if (fine <= inizio) continue;
      final a = geometria.mezzeria[inizio];
      final b = geometria.mezzeria[fine];
      final mezzo = (a + b) / 2;

      final quota = i < quote.length ? quote[i] : 0.0;
      final etichetta = i < profilo.tratti.length
          ? profilo.tratti[i].etichetta
          : '';

      final posizione = _scostato(vista, mezzo, _fuori(vista, a, b, centro), 24);
      final rettangolo = _pastiglia(
        tela,
        posizione,
        '$etichetta  ${FormatoNumero.misura(quota)}',
        sfondo: colori.sfondo,
        bordo: colori.bordoLamiera,
        coloreTesto: colori.testoQuota,
      );
      zone.add(ZonaTocco(
        area: _bersaglio(rettangolo),
        tipo: TipoZona.lato,
        indice: i,
      ));
    }

    // --- badge delle pieghe ------------------------------------------------
    for (final arco in geometria.archi) {
      final j = arco.indicePiega;
      if (j >= profilo.pieghe.length) continue;
      final piega = profilo.pieghe[j];
      final medio =
          geometria.mezzeria[(arco.indiceInizio + arco.indiceFine) ~/ 2];

      // Fuori dalla piega, lungo la bisettrice: è lo spazio libero.
      var direzione = (medio - arco.centro).normalizzato();
      if (direzione.lunghezza < 0.5) direzione = const Vec2(0, 1);
      final schermo = _versoSchermo(vista, medio, direzione);

      final posizione = vista.aPixel(medio) + schermo * 30;
      tela.drawCircle(vista.aPixel(medio), 5,
          Paint()..color = colori.lineaDiPiega);

      final rettangolo = _pastiglia(
        tela,
        posizione,
        '${j + 1}   ${FormatoNumero.gradi(piega.angoloFormato, decimali: 0)}',
        sfondo: colori.lineaDiPiega,
        bordo: colori.lineaDiPiega,
        coloreTesto: Colors.white,
        grassetto: true,
      );
      zone.add(ZonaTocco(
        area: _bersaglio(rettangolo),
        tipo: TipoZona.piega,
        indice: j,
      ));
    }

    if (!modificabile) return;

    // --- i due «+» ---------------------------------------------------------
    _piu(tela, vista, primo: true);
    _piu(tela, vista, primo: false);
  }

  /// Indici di inizio e fine di ogni tratto rettilineo dentro la mezzeria.
  List<(int, int)> _estremiTratti() {
    final risultato = <(int, int)>[];
    for (var i = 0; i <= geometria.archi.length; i++) {
      final inizio = i == 0 ? 0 : geometria.archi[i - 1].indiceFine;
      final fine = i < geometria.archi.length
          ? geometria.archi[i].indiceInizio
          : geometria.mezzeria.length - 1;
      risultato.add((inizio, fine));
    }
    return risultato;
  }

  /// Normale al segmento rivolta dalla parte opposta al centro del pezzo.
  Vec2 _fuori(Vista2D vista, Vec2 a, Vec2 b, Vec2 centro) {
    var n = (b - a).perpendicolare.normalizzato();
    if (n.lunghezza < 0.5) return const Vec2(0, 1);
    final mezzo = (a + b) / 2;
    if (n.dot(mezzo - centro) < 0) n = -n;
    return n;
  }

  /// Converte una direzione del modello in una direzione sullo schermo.
  /// Serve perché l'asse y del disegno punta in alto e quello della tela in
  /// basso: scostare "verso l'esterno" senza questa conversione sposta le
  /// etichette dalla parte sbagliata.
  Offset _versoSchermo(Vista2D vista, Vec2 punto, Vec2 direzione) {
    final da = vista.aPixel(punto);
    final a = vista.aPixel(punto + direzione);
    final d = a - da;
    final lung = d.distance;
    return lung < 0.001 ? const Offset(0, -1) : d / lung;
  }

  Offset _scostato(Vista2D vista, Vec2 punto, Vec2 direzione, double px) =>
      vista.aPixel(punto) + _versoSchermo(vista, punto, direzione) * px;

  void _piu(Canvas tela, Vista2D vista, {required bool primo}) {
    final punti = geometria.mezzeria;
    final punto = primo ? punti.first : punti.last;
    final vicino = primo ? punti[1] : punti[punti.length - 2];
    var direzione = (punto - vicino).normalizzato();
    if (direzione.lunghezza < 0.5) direzione = Vec2(primo ? -1 : 1, 0);

    final posizione = _scostato(vista, punto, direzione, 26);
    const raggio = 17.0;

    tela.drawCircle(posizione, raggio, Paint()..color = colori.lineaDiPiega);
    tela.drawCircle(
      posizione,
      raggio,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final segno = TextPainter(
      text: const TextSpan(
        text: '+',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    segno.paint(tela, posizione - Offset(segno.width / 2, segno.height / 2));

    zone.add(ZonaTocco(
      area: _bersaglio(
        Rect.fromCircle(center: posizione, radius: raggio),
      ),
      tipo: primo ? TipoZona.aggiungiInizio : TipoZona.aggiungiFine,
    ));
  }

  /// Disegna un'etichetta su pastiglia e restituisce il rettangolo occupato.
  Rect _pastiglia(
    Canvas tela,
    Offset centro,
    String testo, {
    required Color sfondo,
    required Color bordo,
    required Color coloreTesto,
    bool grassetto = false,
  }) {
    final pittore = TextPainter(
      text: TextSpan(
        text: testo,
        style: TextStyle(
          color: coloreTesto,
          fontSize: 14,
          fontWeight: grassetto ? FontWeight.w700 : FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rettangolo = Rect.fromCenter(
      center: centro,
      width: pittore.width + 18,
      height: pittore.height + 12,
    );
    final arrotondato =
        RRect.fromRectAndRadius(rettangolo, const Radius.circular(8));

    tela.drawRRect(arrotondato, Paint()..color = sfondo);
    tela.drawRRect(
      arrotondato,
      Paint()
        ..color = bordo
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    pittore.paint(
      tela,
      rettangolo.center - Offset(pittore.width / 2, pittore.height / 2),
    );
    return rettangolo;
  }

  /// Allarga l'area fino al bersaglio minimo toccabile.
  Rect _bersaglio(Rect r) => Rect.fromCenter(
        center: r.center,
        width: math.max(r.width, ZonaTocco.latoMinimo),
        height: math.max(r.height, ZonaTocco.latoMinimo),
      );

  @override
  bool shouldRepaint(PainterProfilo vecchio) => true;
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
