import 'vec2.dart';

/// Rettangolo di ingombro allineato agli assi.
class Rettangolo {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const Rettangolo(this.minX, this.minY, this.maxX, this.maxY);

  static Rettangolo daPunti(Iterable<Vec2> punti) {
    if (punti.isEmpty) return const Rettangolo(0, 0, 0, 0);
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final p in punti) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    return Rettangolo(minX, minY, maxX, maxY);
  }

  double get larghezza => maxX - minX;
  double get altezza => maxY - minY;
  Vec2 get centro => Vec2((minX + maxX) / 2, (minY + maxY) / 2);

  /// Vero se i due ingombri si sovrappongono, con un margine di tolleranza.
  /// È il filtro rapido che evita i test poligono-poligono inutili.
  bool interseca(Rettangolo altro, [double margine = 0]) =>
      minX - margine <= altro.maxX &&
      maxX + margine >= altro.minX &&
      minY - margine <= altro.maxY &&
      maxY + margine >= altro.minY;

  Rettangolo espanso(double quanto) =>
      Rettangolo(minX - quanto, minY - quanto, maxX + quanto, maxY + quanto);

  Rettangolo unito(Rettangolo altro) => Rettangolo(
        minX < altro.minX ? minX : altro.minX,
        minY < altro.minY ? minY : altro.minY,
        maxX > altro.maxX ? maxX : altro.maxX,
        maxY > altro.maxY ? maxY : altro.maxY,
      );

  @override
  String toString() => 'Rettangolo('
      '${minX.toStringAsFixed(2)}, ${minY.toStringAsFixed(2)} → '
      '${maxX.toStringAsFixed(2)}, ${maxY.toStringAsFixed(2)})';
}

/// Poligono semplice, chiuso implicitamente (l'ultimo vertice si ricongiunge al
/// primo).
///
/// Deliberatamente **non** si assume la convessità: la sagoma di un punzone a
/// collo d'oca è concava, ed è proprio il caso che conta. Per questo tutti i
/// test geometrici usano ray casting e distanze fra segmenti, mai SAT.
class Poligono {
  final List<Vec2> vertici;

  const Poligono(this.vertici);

  bool get eValido => vertici.length >= 3;

  Rettangolo get ingombro => Rettangolo.daPunti(vertici);

  /// I lati come coppie di vertici consecutivi, incluso quello di chiusura.
  Iterable<(Vec2, Vec2)> get lati sync* {
    for (var i = 0; i < vertici.length; i++) {
      yield (vertici[i], vertici[(i + 1) % vertici.length]);
    }
  }

  /// Area con segno: positiva se i vertici sono in senso antiorario.
  double get areaConSegno {
    var somma = 0.0;
    for (final (a, b) in lati) {
      somma += a.cross(b);
    }
    return somma / 2;
  }

  /// Test di appartenenza per ray casting (regola pari-dispari).
  bool contiene(Vec2 p) {
    var dentro = false;
    for (var i = 0, j = vertici.length - 1; i < vertici.length; j = i++) {
      final vi = vertici[i];
      final vj = vertici[j];
      if ((vi.y > p.y) != (vj.y > p.y)) {
        final t = (p.y - vi.y) / (vj.y - vi.y);
        if (p.x < vi.x + t * (vj.x - vi.x)) dentro = !dentro;
      }
    }
    return dentro;
  }

  Poligono trasformato({
    double rotazione = 0,
    Vec2 traslazione = Vec2.zero,
    Vec2 pivot = Vec2.zero,
  }) {
    return Poligono([
      for (final v in vertici) v.ruotato(rotazione, pivot) + traslazione,
    ]);
  }

  Poligono traslato(Vec2 offset) =>
      Poligono([for (final v in vertici) v + offset]);

  /// Specchiato rispetto all'asse y. L'ordine dei vertici viene invertito per
  /// conservare il verso di percorrenza.
  Poligono get specchiatoSuY =>
      Poligono([for (final v in vertici.reversed) v.specchiatoSuY]);

  @override
  String toString() => 'Poligono(${vertici.length} vertici, $ingombro)';
}
