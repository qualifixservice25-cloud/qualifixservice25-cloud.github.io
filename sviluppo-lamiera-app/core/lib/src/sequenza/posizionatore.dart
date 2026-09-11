import 'dart:math' as math;

import '../geometria/vec2.dart';
import '../piega/calcolo_piega.dart';
import '../profilo/geometria_profilo.dart';
import '../profilo/profilo_lamiera.dart';
import '../utensili/utensili.dart';

/// Dove si trova il pezzo mentre una piega si sta formando.
///
/// È il passaggio che di solito viene approssimato male, e sbagliarlo rende
/// inutile ogni controllo di collisione: la lamiera non resta appoggiata sul
/// piano della cava, scende dentro la V mentre si piega.
abstract final class PosizionatorePezzo {
  /// Quota del centro di curvatura sopra il piano delle spalle.
  ///
  ///     yc = (Ro − (V/2)·sin φ) / cos φ        con φ = (180 − θ)/2
  ///
  /// La superficie esterna è un arco di raggio Ro tangente alle due rette di
  /// appoggio che passano per le spalle della cava; per simmetria il centro
  /// sta sull'asse verticale.
  ///
  /// Con θ = 180° (lamiera piatta) restituisce Ro, cioè la lamiera appoggia
  /// esattamente sul piano delle spalle: la formula copre anche il caso
  /// iniziale senza eccezioni.
  static double quotaCentro({
    required double aperturaV,
    required double angoloIncluso,
    required double raggioEsterno,
  }) {
    final phi = gradiInRadianti((180 - angoloIncluso.clamp(1.0, 180.0)) / 2);
    final cos = math.cos(phi);
    if (cos.abs() < 1e-6) return double.infinity;
    return (raggioEsterno - (aperturaV / 2) * math.sin(phi)) / cos;
  }

  /// Di quanto il pezzo scende dentro la cava, in millimetri.
  static double penetrazione({
    required double aperturaV,
    required double angoloIncluso,
    required double raggioEsterno,
  }) {
    final yc = quotaCentro(
      aperturaV: aperturaV,
      angoloIncluso: angoloIncluso,
      raggioEsterno: raggioEsterno,
    );
    if (!yc.isFinite) return double.infinity;
    return -(yc - raggioEsterno);
  }

  /// Quota della punta del punzone a quel momento della corsa.
  static double quotaPuntaPunzone({
    required double aperturaV,
    required double angoloIncluso,
    required double raggioInterno,
    required double raggioPunta,
    required double spessore,
  }) {
    final yc = quotaCentro(
      aperturaV: aperturaV,
      angoloIncluso: angoloIncluso,
      raggioEsterno: raggioInterno + spessore,
    );
    if (!yc.isFinite) return double.negativeInfinity;
    return yc - raggioInterno + raggioPunta;
  }

  /// Vero se il pezzo tocca il fondo della cava invece di piegarsi in aria.
  static bool vaInBattuta({
    required Matrice matrice,
    required double angoloIncluso,
    required double raggioEsterno,
  }) {
    final scesa = penetrazione(
      aperturaV: matrice.aperturaV,
      angoloIncluso: angoloIncluso,
      raggioEsterno: raggioEsterno,
    );
    return scesa >= matrice.profondita;
  }

  /// Costruisce il pezzo e lo posa sulla cava, con la piega [indicePiega]
  /// centrata e i lembi rivolti verso l'alto.
  ///
  /// [giaPiegate] sono le pieghe già formate ai loro angoli finali; tutte le
  /// altre restano piatte. [angoloIncluso] è l'angolo della piega in corso in
  /// questo istante della corsa: 180° a inizio corsa, l'angolo finale a fondo
  /// corsa.
  static GeometriaProfilo posa({
    required ProfiloLamiera profilo,
    required List<double> trattiPiani,
    required List<RisultatoPiega> pieghe,
    required Matrice matrice,
    required int indicePiega,
    required Set<int> giaPiegate,
    required double angoloIncluso,
    bool ribaltato = false,
    int segmentiArco = CostruttoreGeometria.segmentiArcoPredefiniti,
  }) {
    final angoli = <int, double>{};
    for (var j = 0; j < profilo.pieghe.length; j++) {
      if (j == indicePiega) {
        angoli[j] = angoloIncluso;
      } else if (giaPiegate.contains(j)) {
        angoli[j] = profilo.pieghe[j].angoloFormato;
      } else {
        angoli[j] = 180;
      }
    }

    final locale = CostruttoreGeometria.costruisci(
      profilo: profilo,
      trattiPiani: trattiPiani,
      pieghe: pieghe,
      angoliCorrenti: angoli,
      ribaltato: ribaltato,
      segmentiArco: segmentiArco,
    );

    final arco = locale.archi.firstWhere(
      (a) => a.indicePiega == indicePiega,
      orElse: () => locale.archi.first,
    );

    final raggioEsterno = pieghe[indicePiega].raggioInterno + profilo.spessore;
    final yc = quotaCentro(
      aperturaV: matrice.aperturaV,
      angoloIncluso: angoloIncluso,
      raggioEsterno: raggioEsterno,
    );
    if (!yc.isFinite) return locale;

    // Si porta la bisettrice della piega a puntare verso il basso: è la
    // condizione che mette i due lembi simmetrici sopra la cava.
    final bisettrice = arco.bisettriceVerso(locale.mezzeria);
    if (bisettrice.lunghezza < Vec2.epsilon) return locale;

    final rotazione = -math.pi / 2 - bisettrice.angolo;
    final ruotata = locale.trasformata(rotazione: rotazione, pivot: arco.centro);

    // Dopo la rotazione il centro è ancora nel pivot: basta traslarlo.
    final traslazione = Vec2(0, yc) - arco.centro;
    return ruotata.trasformata(traslazione: traslazione);
  }
}
