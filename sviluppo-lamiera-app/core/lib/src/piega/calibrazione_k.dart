import 'dart:math' as math;

import '../geometria/vec2.dart';
import '../materiali/materiale.dart';
import '../profilo/profilo_lamiera.dart';
import '../sviluppo/calcolo_sviluppo.dart';
import '../utensili/utensili.dart';
import 'calcolo_piega.dart';
import 'fattore_k.dart';

/// Taratura del fattore K su un pezzo di prova.
///
/// È la funzione che trasforma l'app da «fidati della formula» a «fidati del
/// tuo acciaio»: l'operatore piega un provino, misura lo sviluppo che gli è
/// servito davvero, e da lì si ricava il fattore K della *sua* macchina con
/// *quel* materiale.
abstract final class CalibrazioneK {
  /// Fattore K che spiega una detrazione misurata.
  ///
  ///     K = [2·tan(β/2)·(Ri+S) − BD] / [(π/180)·β·S] − Ri/S
  ///
  /// Restituisce null se il risultato cade fuori dall'intervallo fisicamente
  /// possibile: in quel caso la misura o il raggio non tornano, ed è meglio
  /// dirlo che restituire un numero senza senso.
  static double? kDaDetrazione({
    required double bdMisurato,
    required double angoloRotazione,
    required double raggioInterno,
    required double spessore,
  }) {
    if (spessore <= 0 || angoloRotazione <= 0) return null;
    final beta = gradiInRadianti(angoloRotazione);
    final denominatore = beta * spessore;
    if (denominatore.abs() < Vec2.epsilon) return null;

    final ossbDoppio =
        2 * math.tan(beta / 2) * (raggioInterno + spessore);
    final k = (ossbDoppio - bdMisurato) / denominatore - raggioInterno / spessore;

    if (!k.isFinite || k < 0 || k > FattoreK.massimo + 1e-6) return null;
    return k.clamp(0.0, FattoreK.massimo);
  }

  /// Fattore K ricavato dalle quote esterne e dallo sviluppo misurato di una
  /// squadretta a una sola piega.
  static double? kDaProvino({
    required double latoEsterno1,
    required double latoEsterno2,
    required double sviluppoMisurato,
    required double angoloFormato,
    required double raggioInterno,
    required double spessore,
  }) {
    final bd = latoEsterno1 + latoEsterno2 - sviluppoMisurato;
    return kDaDetrazione(
      bdMisurato: bd,
      angoloRotazione: 180 - angoloFormato,
      raggioInterno: raggioInterno,
      spessore: spessore,
    );
  }

  /// Intervallo entro cui si cerca il moltiplicatore di taratura.
  static const double correzioneMinima = 0.2;
  static const double correzioneMassima = 3.0;

  /// Moltiplicatore da salvare sul materiale perché lo sviluppo calcolato del
  /// [profilo] coincida con quello misurato.
  ///
  /// Si procede per bisezione invece che invertendo la formula, perché il
  /// fattore K è limitato a 0,5 e la relazione smette di essere lineare
  /// proprio dove serve.
  static double? correzioneDaSviluppoMisurato({
    required ProfiloLamiera profilo,
    required Inventario inventario,
    required double sviluppoMisurato,
    double tolleranza = 1e-4,
    int iterazioniMassime = 60,
  }) {
    if (!sviluppoMisurato.isFinite || sviluppoMisurato <= 0) return null;

    double? sviluppoCon(double correzione) {
      final tarato = profilo.copiaCon(
        materiale: profilo.materiale.copiaCon(correzioneK: correzione),
      );
      final risultato = CalcoloSviluppo.calcola(tarato, inventario);
      return risultato.lunghezzaTotale.isFinite
          ? risultato.lunghezzaTotale
          : null;
    }

    final basso = sviluppoCon(correzioneMinima);
    final alto = sviluppoCon(correzioneMassima);
    if (basso == null || alto == null) return null;

    // Lo sviluppo cresce col fattore K: fuori da questo intervallo non c'è
    // soluzione, e dirlo è più utile che restituire un estremo.
    if (sviluppoMisurato < basso - tolleranza) return null;
    if (sviluppoMisurato > alto + tolleranza) return null;

    var a = correzioneMinima;
    var b = correzioneMassima;
    for (var i = 0; i < iterazioniMassime; i++) {
      final medio = (a + b) / 2;
      final valore = sviluppoCon(medio);
      if (valore == null) return null;
      if ((valore - sviluppoMisurato).abs() <= tolleranza) return medio;
      if (valore < sviluppoMisurato) {
        a = medio;
      } else {
        b = medio;
      }
    }
    return (a + b) / 2;
  }

  /// Il materiale con la correzione applicata, pronto da salvare.
  static Materiale materialeTarato(Materiale materiale, double correzione) =>
      materiale.copiaCon(
        correzioneK: correzione.clamp(correzioneMinima, correzioneMassima),
      );

  /// Fattore K teorico per la stessa configurazione, utile da mostrare
  /// accanto a quello tarato per far vedere di quanto ci si discosta.
  static double kTeorico({
    required double raggioInterno,
    required double spessore,
  }) =>
      FattoreK.fattoreK(raggioInterno, spessore);

  /// Raggio interno da usare nella taratura quando l'operatore non l'ha
  /// misurato: quello che produce la cava.
  static double raggioDaCava(double aperturaV, Materiale materiale) =>
      CalcoloPiega.raggioInternoDaCava(aperturaV, materiale);
}
