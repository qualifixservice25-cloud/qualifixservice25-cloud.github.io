import 'dart:math' as math;

import '../geometria/poligono.dart';
import '../geometria/vec2.dart';

/// Generazione delle sagome degli utensili a partire dai numeri che
/// l'operatore legge sul fianco dell'utensile o sul catalogo.
///
/// Nessun editor di profili: un collo d'oca si descrive con due misure, non
/// disegnando un poligono. Le sagome servono sia al disegno sia — soprattutto —
/// al controllo delle collisioni, quindi sono geometria vera, non icone.
abstract final class SagomaUtensile {
  /// Punzone con la punta nell'origine e il corpo verso l'alto.
  ///
  /// [angoloPunta] è l'angolo compreso fra i due fianchi (88°, 60°, 30°…),
  /// [raggioPunta] il raggio dello spigolo che tocca la lamiera, [altezza]
  /// l'ingombro verticale utile e [larghezzaCorpo] la larghezza del fusto.
  ///
  /// Quando [gollaProfondita] è maggiore di zero il fusto rientra di quella
  /// misura per un tratto alto [gollaAltezza]: è il collo d'oca, che lascia
  /// passare il lembo già piegato. Il poligono che ne esce è concavo — per
  /// questo tutti i test di collisione lavorano su poligoni generici.
  static Poligono punzone({
    required double angoloPunta,
    required double raggioPunta,
    required double altezza,
    double larghezzaCorpo = 30,
    double gollaProfondita = 0,
    double gollaAltezza = 0,
    bool gollaADestra = true,
    int segmentiRaggio = 10,
  }) {
    final semiAngolo = gradiInRadianti(angoloPunta.clamp(5.0, 179.0) / 2);
    final raggio = math.max(raggioPunta, 0.01);
    final semiLarghezza = math.max(larghezzaCorpo / 2, 0.5);

    final sin = math.sin(semiAngolo);
    final cos = math.cos(semiAngolo);

    // Punto in cui il fianco rettilineo si stacca dall'arco di punta.
    final tangente = Vec2(raggio * cos, raggio * (1 - sin));

    final vertici = <Vec2>[];

    // Larghezza utile di ciascun lato: quello con la golla rientra.
    final profonditaGolla = math.max(gollaProfondita, 0);
    final altezzaGolla = math.max(gollaAltezza, 0);
    final haGolla = profonditaGolla > 0 && altezzaGolla > 0;
    final semiSinistra =
        haGolla && !gollaADestra ? semiLarghezza - profonditaGolla : semiLarghezza;
    final semiDestra =
        haGolla && gollaADestra ? semiLarghezza - profonditaGolla : semiLarghezza;

    // --- lato sinistro, dall'alto verso la punta ---------------------------
    vertici.add(Vec2(-semiLarghezza, altezza));
    if (haGolla && !gollaADestra) {
      final fine = _fineFianco(tangente, semiSinistra, sin, cos, altezza);
      vertici.add(Vec2(-semiLarghezza, fine.y + altezzaGolla));
      vertici.add(Vec2(-semiSinistra, fine.y + altezzaGolla));
      vertici.add(Vec2(-fine.x, fine.y));
    } else {
      final fine = _fineFianco(tangente, semiSinistra, sin, cos, altezza);
      vertici.add(Vec2(-fine.x, fine.y));
    }

    // --- arco di punta, da sinistra a destra passando per l'origine --------
    final daAngolo = semiAngolo - math.pi;
    final aAngolo = -semiAngolo;
    final passi = math.max(segmentiRaggio, 2);
    for (var i = 0; i <= passi; i++) {
      final t = daAngolo + (aAngolo - daAngolo) * i / passi;
      vertici.add(Vec2(raggio * math.cos(t), raggio + raggio * math.sin(t)));
    }

    // --- lato destro, dalla punta verso l'alto -----------------------------
    if (haGolla && gollaADestra) {
      final fine = _fineFianco(tangente, semiDestra, sin, cos, altezza);
      vertici.add(Vec2(fine.x, fine.y));
      vertici.add(Vec2(semiDestra, fine.y + altezzaGolla));
      vertici.add(Vec2(semiLarghezza, fine.y + altezzaGolla));
    } else {
      final fine = _fineFianco(tangente, semiDestra, sin, cos, altezza);
      vertici.add(Vec2(fine.x, fine.y));
    }
    vertici.add(Vec2(semiLarghezza, altezza));

    return Poligono(vertici);
  }

  /// Dove il fianco rettilineo incontra il fusto, o l'altezza massima se il
  /// fusto è più stretto di quanto il fianco arrivi a coprire.
  static Vec2 _fineFianco(
    Vec2 tangente,
    double semiLarghezza,
    double sin,
    double cos,
    double altezza,
  ) {
    if (semiLarghezza <= tangente.x || sin < Vec2.epsilon) {
      // Fusto più stretto della punta: il fianco sale dritto.
      return Vec2(tangente.x, math.max(altezza, tangente.y));
    }
    final passo = (semiLarghezza - tangente.x) / sin;
    final y = tangente.y + passo * cos;
    if (y >= altezza) {
      final passoLimite = (altezza - tangente.y) / math.max(cos, Vec2.epsilon);
      return Vec2(tangente.x + passoLimite * sin, altezza);
    }
    return Vec2(semiLarghezza, y);
  }

  /// Profondità della cava: quanto scende l'apice della V sotto il piano delle
  /// spalle.
  static double profonditaCava(double aperturaV, double angoloV) {
    final semiAngolo = gradiInRadianti(angoloV.clamp(5.0, 179.0) / 2);
    final tan = math.tan(semiAngolo);
    return tan < Vec2.epsilon ? 0 : (aperturaV / 2) / tan;
  }

  /// Matrice a V con le spalle sul piano `y = 0` e l'apice in basso.
  ///
  /// Le spalle sono raccordate con un arco di raggio [raggioSpalla] tangente
  /// al piano superiore e al fianco della V: è su quel raccordo che la lamiera
  /// struscia mentre si forma, quindi va rappresentato davvero.
  static Poligono matriceAV({
    required double aperturaV,
    required double angoloV,
    required double raggioSpalla,
    required double altezza,
    double larghezza = 0,
    int segmentiRaggio = 6,
  }) {
    final semiAngolo = gradiInRadianti(angoloV.clamp(5.0, 179.0) / 2);
    final sin = math.sin(semiAngolo);
    final cos = math.cos(semiAngolo);
    final semiApertura = math.max(aperturaV / 2, 0.5);
    final profondita = profonditaCava(aperturaV, angoloV);
    final altezzaCorpo = math.max(altezza, profondita + 2);
    final semiLarghezza = larghezza > 0
        ? larghezza / 2
        : math.max(aperturaV * 0.8, semiApertura + 20);

    // Centro del raccordo di spalla: a distanza r dal piano superiore e dal
    // fianco della V.
    final raggio = math.max(raggioSpalla, 0.01);
    final centroX = semiApertura + raggio * (1 - sin) / math.max(cos, Vec2.epsilon);
    const centroY = 0.0;
    final centro = Vec2(centroX, centroY - raggio);

    List<Vec2> arcoSpallaDestra() {
      // Dall'appoggio sul piano superiore (90°) al distacco sul fianco.
      final da = math.pi / 2;
      final a = math.pi - semiAngolo;
      final passi = math.max(segmentiRaggio, 2);
      return [
        for (var i = 0; i <= passi; i++)
          () {
            final t = da + (a - da) * i / passi;
            return Vec2(
              centro.x + raggio * math.cos(t),
              centro.y + raggio * math.sin(t),
            );
          }(),
      ];
    }

    final arcoDestro = arcoSpallaDestra();
    final arcoSinistro = [
      for (final p in arcoDestro.reversed) Vec2(-p.x, p.y),
    ];

    final vertici = <Vec2>[
      Vec2(-semiLarghezza, -altezzaCorpo),
      Vec2(semiLarghezza, -altezzaCorpo),
      Vec2(semiLarghezza, 0),
      // piano superiore verso il raccordo destro
      ...arcoDestro,
      // fianco destro fino all'apice
      Vec2(0, -profondita),
      // fianco sinistro e raccordo
      ...arcoSinistro,
      Vec2(-semiLarghezza, 0),
    ];

    return Poligono(vertici);
  }
}
