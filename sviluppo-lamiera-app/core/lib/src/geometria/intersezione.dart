import 'dart:math' as math;

import 'poligono.dart';
import 'vec2.dart';

/// Orientamento della terna (a, b, c): >0 antiorario, <0 orario, 0 allineati.
double _orientamento(Vec2 a, Vec2 b, Vec2 c) => (b - a).cross(c - a);

bool _suSegmento(Vec2 a, Vec2 b, Vec2 p) =>
    p.x <= math.max(a.x, b.x) + Vec2.epsilon &&
    p.x >= math.min(a.x, b.x) - Vec2.epsilon &&
    p.y <= math.max(a.y, b.y) + Vec2.epsilon &&
    p.y >= math.min(a.y, b.y) - Vec2.epsilon;

/// Vero se i segmenti a1-a2 e b1-b2 si intersecano, casi degeneri e
/// sovrapposizioni collineari compresi.
bool segmentiSiIntersecano(Vec2 a1, Vec2 a2, Vec2 b1, Vec2 b2) {
  final o1 = _orientamento(a1, a2, b1);
  final o2 = _orientamento(a1, a2, b2);
  final o3 = _orientamento(b1, b2, a1);
  final o4 = _orientamento(b1, b2, a2);

  if (o1 * o2 < 0 && o3 * o4 < 0) return true;

  if (o1.abs() < Vec2.epsilon && _suSegmento(a1, a2, b1)) return true;
  if (o2.abs() < Vec2.epsilon && _suSegmento(a1, a2, b2)) return true;
  if (o3.abs() < Vec2.epsilon && _suSegmento(b1, b2, a1)) return true;
  if (o4.abs() < Vec2.epsilon && _suSegmento(b1, b2, a2)) return true;

  return false;
}

/// Distanza fra il punto [p] e il segmento a-b.
double distanzaPuntoSegmento(Vec2 p, Vec2 a, Vec2 b) {
  final ab = b - a;
  final lungQuadra = ab.lunghezzaQuadra;
  if (lungQuadra < Vec2.epsilon) return p.distanzaDa(a);
  var t = (p - a).dot(ab) / lungQuadra;
  t = t.clamp(0.0, 1.0);
  return p.distanzaDa(a + ab * t);
}

/// Distanza minima fra due segmenti. Zero se si toccano o si intersecano.
double distanzaSegmentoSegmento(Vec2 a1, Vec2 a2, Vec2 b1, Vec2 b2) {
  if (segmentiSiIntersecano(a1, a2, b1, b2)) return 0;
  return [
    distanzaPuntoSegmento(a1, b1, b2),
    distanzaPuntoSegmento(a2, b1, b2),
    distanzaPuntoSegmento(b1, a1, a2),
    distanzaPuntoSegmento(b2, a1, a2),
  ].reduce(math.min);
}

/// Esito di una misura di gioco fra il pezzo e un utensile.
class EsitoGioco {
  /// Vero se c'è compenetrazione vera e propria.
  final bool collide;

  /// Distanza minima in mm. Negativa quando il pezzo entra nell'utensile: in
  /// quel caso è la profondità di penetrazione stimata, col segno.
  final double gioco;

  /// Il punto del pezzo dove il gioco è minimo: è quello da mostrare in rosso.
  final Vec2? puntoCritico;

  const EsitoGioco({
    required this.collide,
    required this.gioco,
    this.puntoCritico,
  });

  static const EsitoGioco nessunContatto =
      EsitoGioco(collide: false, gioco: double.infinity);

  @override
  String toString() => collide
      ? 'EsitoGioco(collide, ${gioco.toStringAsFixed(2)} mm)'
      : 'EsitoGioco(libero, ${gioco.toStringAsFixed(2)} mm)';
}

/// Gioco minimo fra una polilinea (il contorno del pezzo) e un poligono
/// (la sagoma di un utensile).
///
/// [indiciEsclusi] elenca i vertici della polilinea che stanno legittimamente a
/// contatto con l'utensile — la zona dove il punzone *deve* toccare la lamiera.
/// Senza questa esclusione ogni piega risulterebbe una collisione.
EsitoGioco giocoPolilineaPoligono(
  List<Vec2> polilinea,
  Poligono utensile, {
  Set<int> indiciEsclusi = const {},
}) {
  if (polilinea.length < 2 || !utensile.eValido) {
    return EsitoGioco.nessunContatto;
  }

  final ingombroUtensile = utensile.ingombro;
  var giocoMinimo = double.infinity;
  Vec2? puntoCritico;
  var collide = false;

  for (var i = 0; i < polilinea.length - 1; i++) {
    if (indiciEsclusi.contains(i) && indiciEsclusi.contains(i + 1)) continue;

    final a = polilinea[i];
    final b = polilinea[i + 1];

    // Filtro rapido sull'ingombro: salta i segmenti troppo lontani.
    final ingombroSegmento = Rettangolo.daPunti([a, b]);
    if (!ingombroSegmento.interseca(ingombroUtensile, giocoMinimo.isFinite ? giocoMinimo : 0)) {
      continue;
    }

    // Un estremo dentro il poligono significa compenetrazione.
    if (!indiciEsclusi.contains(i) && utensile.contiene(a)) {
      final profondita = _profonditaIn(a, utensile);
      if (-profondita < giocoMinimo) {
        giocoMinimo = -profondita;
        puntoCritico = a;
      }
      collide = true;
    }

    for (final (u, v) in utensile.lati) {
      final d = distanzaSegmentoSegmento(a, b, u, v);
      if (d < giocoMinimo) {
        giocoMinimo = d;
        puntoCritico = a.distanzaDa(u) < b.distanzaDa(u) ? a : b;
      }
      if (d <= Vec2.epsilon) collide = true;
    }
  }

  if (!giocoMinimo.isFinite) return EsitoGioco.nessunContatto;
  return EsitoGioco(
    collide: collide,
    gioco: giocoMinimo,
    puntoCritico: puntoCritico,
  );
}

/// Quanto in profondità la polilinea entra dentro il poligono, in mm.
///
/// Zero quando lo sfiora soltanto. Serve dove il contatto è **normale** e solo
/// la compenetrazione è un problema: la lamiera appoggia sulla cava per tutta
/// la sua lunghezza, e chiamare collisione quell'appoggio renderebbe
/// impossibile qualunque piega.
///
/// I segmenti vengono campionati all'interno e non solo agli estremi, perché
/// un lembo lungo può attraversare il corpo dell'utensile senza che nessuno
/// dei suoi due estremi ci finisca dentro.
double penetrazioneMassima(
  List<Vec2> polilinea,
  Poligono poligono, {
  Set<int> indiciEsclusi = const {},
  int campioniPerSegmento = 6,
}) {
  if (polilinea.length < 2 || !poligono.eValido) return 0;

  final ingombro = poligono.ingombro;
  var massima = 0.0;

  void considera(Vec2 p) {
    if (p.x < ingombro.minX ||
        p.x > ingombro.maxX ||
        p.y < ingombro.minY ||
        p.y > ingombro.maxY) {
      return;
    }
    if (!poligono.contiene(p)) return;
    final profondita = _profonditaIn(p, poligono);
    if (profondita > massima) massima = profondita;
  }

  for (var i = 0; i < polilinea.length - 1; i++) {
    if (indiciEsclusi.contains(i) && indiciEsclusi.contains(i + 1)) continue;
    final a = polilinea[i];
    final b = polilinea[i + 1];
    if (!indiciEsclusi.contains(i)) considera(a);
    for (var s = 1; s < campioniPerSegmento; s++) {
      considera(a + (b - a) * (s / campioniPerSegmento));
    }
  }
  if (!indiciEsclusi.contains(polilinea.length - 1)) {
    considera(polilinea.last);
  }

  return massima;
}

/// Quanto in profondità sta [p] dentro [poligono]: distanza dal lato più vicino.
double _profonditaIn(Vec2 p, Poligono poligono) {
  var minima = double.infinity;
  for (final (a, b) in poligono.lati) {
    final d = distanzaPuntoSegmento(p, a, b);
    if (d < minima) minima = d;
  }
  return minima.isFinite ? minima : 0;
}
