import 'dart:math' as math;

import '../diagnostica/avvertimento.dart';
import '../formato/formato_numero.dart';
import '../geometria/vec2.dart';
import '../utensili/utensili.dart';

/// Parametri della regola del lato minimo.
///
/// Il coefficiente è **calibrabile**, non cablato: cambia col tipo di cava e
/// con le abitudini dell'officina. Con V16 la regola a 0,65 dà 10,4 mm mentre
/// molte tabelle costruttore indicano ~11 mm — chi vuole allinearsi alle
/// proprie alza il coefficiente a 0,69.
class ParametriLatoMinimo {
  /// Moltiplicatore della regola pratica `b_min = coefficiente · V`.
  final double coefficiente;

  /// Usa la variante geometrica basata sulla spalla della cava invece della
  /// regola pratica.
  final bool usaVarianteGeometrica;

  /// Margine aggiunto al risultato, mm.
  final double margineSicurezza;

  const ParametriLatoMinimo({
    this.coefficiente = 0.65,
    this.usaVarianteGeometrica = false,
    this.margineSicurezza = 0,
  });

  ParametriLatoMinimo copiaCon({
    double? coefficiente,
    bool? usaVarianteGeometrica,
    double? margineSicurezza,
  }) {
    return ParametriLatoMinimo(
      coefficiente: coefficiente ?? this.coefficiente,
      usaVarianteGeometrica:
          usaVarianteGeometrica ?? this.usaVarianteGeometrica,
      margineSicurezza: margineSicurezza ?? this.margineSicurezza,
    );
  }

  Map<String, dynamic> aMappa() => {
        'coefficiente': coefficiente,
        'usaVarianteGeometrica': usaVarianteGeometrica,
        'margineSicurezza': margineSicurezza,
      };

  static ParametriLatoMinimo daMappa(Map<String, dynamic> m) =>
      ParametriLatoMinimo(
        coefficiente: (m['coefficiente'] as num?)?.toDouble() ?? 0.65,
        usaVarianteGeometrica:
            (m['usaVarianteGeometrica'] as bool?) ?? false,
        margineSicurezza: (m['margineSicurezza'] as num?)?.toDouble() ?? 0,
      );
}

/// Esito del controllo sul lato minimo.
class EsitoLatoMinimo {
  final bool ammissibile;

  /// Il minimo calcolato per questa cava.
  final double latoMinimo;

  /// Quello che si sta cercando di piegare.
  final double latoRichiesto;

  /// Quanto avanza (positivo) o quanto manca (negativo).
  final double margine;

  final String? nota;

  const EsitoLatoMinimo({
    required this.ammissibile,
    required this.latoMinimo,
    required this.latoRichiesto,
    required this.margine,
    this.nota,
  });

  @override
  String toString() => ammissibile
      ? 'lato ok (+${margine.toStringAsFixed(1)} mm)'
      : 'lato corto (${margine.toStringAsFixed(1)} mm)';
}

/// Il lato minimo piegabile: sotto questa lunghezza il lembo scivola dentro la
/// cava invece di piegarsi.
abstract final class LatoMinimo {
  /// Regola pratica: `b_min = coefficiente · V`.
  static double praticoDaV(double aperturaV, {double coefficiente = 0.65}) =>
      aperturaV * coefficiente;

  /// Variante geometrica: il lembo deve appoggiare oltre la spalla della cava.
  ///
  /// Il lembo scende inclinato di β/2 rispetto al piano, quindi la proiezione
  /// necessaria cresce quando l'angolo si chiude.
  static double geometrico({
    required double aperturaV,
    required double angoloFormato,
    required double raggioSpalla,
    required double spessore,
  }) {
    final semiRotazione = gradiInRadianti((180 - angoloFormato) / 2);
    final cos = math.cos(semiRotazione);
    final proiezione =
        cos.abs() < Vec2.epsilon ? aperturaV : (aperturaV / 2) / cos;
    return proiezione + raggioSpalla + spessore;
  }

  /// Il lato minimo per questa cava e questo angolo, secondo i parametri.
  static double calcola({
    required Matrice matrice,
    required double angoloFormato,
    required double spessore,
    ParametriLatoMinimo parametri = const ParametriLatoMinimo(),
  }) {
    final base = parametri.usaVarianteGeometrica
        ? geometrico(
            aperturaV: matrice.aperturaV,
            angoloFormato: angoloFormato,
            raggioSpalla: matrice.raggioSpalla,
            spessore: spessore,
          )
        : praticoDaV(matrice.aperturaV, coefficiente: parametri.coefficiente);
    return base + parametri.margineSicurezza;
  }

  /// Verifica un lembo contro il minimo.
  static EsitoLatoMinimo verifica({
    required double lunghezzaLato,
    required Matrice matrice,
    required double angoloFormato,
    required double spessore,
    ParametriLatoMinimo parametri = const ParametriLatoMinimo(),
  }) {
    final minimo = calcola(
      matrice: matrice,
      angoloFormato: angoloFormato,
      spessore: spessore,
      parametri: parametri,
    );
    final margine = lunghezzaLato - minimo;
    return EsitoLatoMinimo(
      ammissibile: margine >= 0,
      latoMinimo: minimo,
      latoRichiesto: lunghezzaLato,
      margine: margine,
      nota: parametri.usaVarianteGeometrica
          ? 'variante geometrica sulla spalla'
          : 'regola pratica ${FormatoNumero.fattore(parametri.coefficiente, decimali: 2)} · V',
    );
  }

  /// L'avvertimento corrispondente, o null se il lembo va bene.
  static Avvertimento? avvertimento({
    required EsitoLatoMinimo esito,
    required Matrice matrice,
    int? indicePiega,
  }) {
    if (esito.ammissibile) return null;
    return Avvertimento.errore(
      CodiceAvvertimento.latoMinimo,
      'Lembo di ${FormatoNumero.mm(esito.latoRichiesto)}: con ${matrice.nome} '
      'il minimo piegabile è ${FormatoNumero.mm(esito.latoMinimo)}. '
      'Mancano ${FormatoNumero.mm(esito.margine.abs())} — serve una cava più '
      'stretta.',
      indicePiega: indicePiega,
    );
  }
}
