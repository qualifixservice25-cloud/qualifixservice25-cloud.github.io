import 'dart:math' as math;

/// Calcolo del fattore K secondo DIN 6935.
///
/// Il fattore K dice dove si trova l'asse neutro dentro lo spessore: è la
/// frazione di spessore, misurata dalla faccia interna, alla quale la lamiera
/// non si allunga né si accorcia. Da lì discende tutto lo sviluppo.
abstract final class FattoreK {
  /// Valore massimo fisicamente ammissibile: l'asse neutro non può oltrepassare
  /// la mezzeria dello spessore.
  static const double massimo = 0.5;

  /// Coefficiente `k` grezzo della DIN 6935.
  ///
  ///     k = 0,65 + 0,5 · log₁₀(Ri/S)      limitato a [0, 1]
  ///
  /// Con `Ri/S = 5` restituisce esattamente 1, cioè `K = 0,5`: la formula
  /// contiene già la regola nota per cui oltre i cinque spessori di raggio
  /// l'asse neutro sta in mezzo.
  static double kDin6935(double raggioInterno, double spessore) {
    if (spessore <= 0) return 1.0;
    if (raggioInterno <= 0) return 0.0;
    final rapporto = raggioInterno / spessore;
    final k = 0.65 + 0.5 * (math.log(rapporto) / math.ln10);
    return k.clamp(0.0, 1.0);
  }

  /// Fattore K = k/2, eventualmente corretto dalla taratura del materiale.
  ///
  /// [correzione] è il moltiplicatore ricavato da un pezzo di prova: vale 1
  /// finché l'operatore non ha tarato nulla.
  static double fattoreK(
    double raggioInterno,
    double spessore, {
    double correzione = 1.0,
  }) {
    final k = kDin6935(raggioInterno, spessore);
    final valore = k / 2 * correzione;
    return valore.clamp(0.0, massimo);
  }

  /// Rapporto Ri/S, il parametro da cui dipende tutto il resto.
  static double rapportoRaggioSpessore(double raggioInterno, double spessore) =>
      spessore <= 0 ? 0 : raggioInterno / spessore;
}
