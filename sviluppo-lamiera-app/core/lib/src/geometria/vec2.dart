import 'dart:math' as math;

/// Punto o vettore nel piano della sezione trasversale, sempre in millimetri.
///
/// Il piano è quello che si vede guardando la piegatrice di lato: `x` corre
/// lungo il banco, `y` verso l'alto, con l'origine nella mezzeria della cava
/// sul piano delle spalle.
class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  /// Tolleranza di confronto. Un decimo di micron: ben sotto qualunque
  /// precisione di officina, ma abbastanza sopra l'errore dei double.
  static const double epsilon = 1e-7;

  Vec2 operator +(Vec2 altro) => Vec2(x + altro.x, y + altro.y);
  Vec2 operator -(Vec2 altro) => Vec2(x - altro.x, y - altro.y);
  Vec2 operator *(double fattore) => Vec2(x * fattore, y * fattore);
  Vec2 operator /(double divisore) => Vec2(x / divisore, y / divisore);
  Vec2 operator -() => Vec2(-x, -y);

  double get lunghezzaQuadra => x * x + y * y;
  double get lunghezza => math.sqrt(lunghezzaQuadra);

  /// Direzione in radianti, misurata dall'asse x in senso antiorario.
  double get angolo => math.atan2(y, x);

  /// Vettore unitario nella stessa direzione. Restituisce [zero] se il vettore
  /// è degenere, invece di produrre NaN.
  Vec2 normalizzato() {
    final lung = lunghezza;
    return lung < epsilon ? Vec2.zero : Vec2(x / lung, y / lung);
  }

  /// Ruotato di 90° in senso antiorario. Serve per le normali ai lati.
  Vec2 get perpendicolare => Vec2(-y, x);

  double dot(Vec2 altro) => x * altro.x + y * altro.y;

  /// Prodotto vettoriale scalare: positivo se [altro] sta a sinistra.
  double cross(Vec2 altro) => x * altro.y - y * altro.x;

  double distanzaDa(Vec2 altro) => (this - altro).lunghezza;

  Vec2 ruotato(double radianti, [Vec2 attorno = Vec2.zero]) {
    final cos = math.cos(radianti);
    final sin = math.sin(radianti);
    final d = this - attorno;
    return Vec2(
      attorno.x + d.x * cos - d.y * sin,
      attorno.y + d.x * sin + d.y * cos,
    );
  }

  /// Specchiato rispetto all'asse y: è il ribaltamento del pezzo fra le mani
  /// dell'operatore.
  Vec2 get specchiatoSuY => Vec2(-x, y);

  bool get eFinito => x.isFinite && y.isFinite;

  bool quasiUguale(Vec2 altro, [double tolleranza = epsilon]) =>
      (x - altro.x).abs() <= tolleranza && (y - altro.y).abs() <= tolleranza;

  @override
  bool operator ==(Object other) =>
      other is Vec2 && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'Vec2(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

/// Conversione gradi → radianti. Tutta l'interfaccia parla in gradi, tutta la
/// trigonometria interna in radianti: la conversione sta solo qui.
double gradiInRadianti(double gradi) => gradi * math.pi / 180.0;

/// Conversione radianti → gradi.
double radiantiInGradi(double radianti) => radianti * 180.0 / math.pi;
