import 'package:flutter/rendering.dart';

/// Che cosa si tocca sul disegno del profilo.
enum TipoZona {
  /// La quota di un tratto: apre il tastierino.
  lato,

  /// Il badge dell'angolo: apre la scheda della piega.
  piega,

  /// Il «+» prima del primo tratto.
  aggiungiInizio,

  /// Il «+» dopo l'ultimo tratto.
  aggiungiFine,
}

/// Un'area toccabile registrata dal painter mentre disegna.
///
/// Il painter sa dove ha messo le etichette, il widget no: invece di
/// ricalcolare la stessa geometria due volte (e rischiare che le due copie
/// divergano), il painter riempie questa lista e il widget ci cerca dentro.
class ZonaTocco {
  final Rect area;
  final TipoZona tipo;

  /// Indice del tratto o della piega. Vale -1 per i pulsanti «+».
  final int indice;

  const ZonaTocco({
    required this.area,
    required this.tipo,
    this.indice = -1,
  });

  /// Bersaglio minimo: con i guanti si sbaglia mira, e un'etichetta di testo
  /// è spesso più piccola di un dito.
  static const double latoMinimo = 44;
}
