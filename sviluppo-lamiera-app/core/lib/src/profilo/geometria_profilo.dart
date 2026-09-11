import 'dart:math' as math;

import '../geometria/poligono.dart';
import '../geometria/vec2.dart';
import '../piega/calcolo_piega.dart';
import 'profilo_lamiera.dart';

/// L'arco di una piega dentro la geometria costruita.
class ArcoPiega {
  final int indicePiega;

  /// Centro di curvatura, nel sistema di riferimento della geometria.
  final Vec2 centro;

  /// Raggio della mezzeria dello spessore.
  final double raggioMezzeria;

  /// Angolo di rotazione effettivamente applicato, in radianti, con segno.
  final double rotazione;

  /// Estremi dell'arco dentro la polilinea di mezzeria.
  final int indiceInizio;
  final int indiceFine;

  const ArcoPiega({
    required this.indicePiega,
    required this.centro,
    required this.raggioMezzeria,
    required this.rotazione,
    required this.indiceInizio,
    required this.indiceFine,
  });

  /// Direzione dalla quale il centro "guarda" la metà dell'arco: è la
  /// bisettrice della piega.
  Vec2 bisettriceVerso(List<Vec2> mezzeria) {
    final medio = mezzeria[(indiceInizio + indiceFine) ~/ 2];
    return (medio - centro).normalizzato();
  }
}

/// La sezione del pezzo, formata o in corso di formatura.
///
/// È l'unica fonte di verità geometrica del progetto: la usano sia il disegno
/// sia il controllo delle collisioni, così quello che si vede a schermo è
/// esattamente quello che il motore ha verificato.
class GeometriaProfilo {
  /// La linea di mezzeria dello spessore.
  final List<Vec2> mezzeria;

  /// Contorno spostato di mezzo spessore verso la sinistra del percorso.
  final List<Vec2> contornoA;

  /// Contorno spostato di mezzo spessore verso la destra del percorso.
  final List<Vec2> contornoB;

  final List<ArcoPiega> archi;
  final double spessore;

  GeometriaProfilo({
    required this.mezzeria,
    required this.contornoA,
    required this.contornoB,
    required this.archi,
    required this.spessore,
  });

  /// Il contorno chiuso della sezione: si percorre un lato all'andata e
  /// l'altro al ritorno.
  late final Poligono sezione =
      Poligono([...contornoA, ...contornoB.reversed]);

  /// La sezione come polilinea chiusa, pronta per i test di collisione.
  late final List<Vec2> contornoChiuso = [
    ...contornoA,
    ...contornoB.reversed,
    if (contornoA.isNotEmpty) contornoA.first,
  ];

  late final Rettangolo ingombro = Rettangolo.daPunti(contornoChiuso);

  /// Il punto più alto del pezzo: serve a capire se ci sta sotto l'utensile.
  double get altezzaMassima => ingombro.maxY;

  /// Quanto il pezzo scende sotto il piano delle spalle.
  double get quotaMinima => ingombro.minY;

  GeometriaProfilo trasformata({
    double rotazione = 0,
    Vec2 traslazione = Vec2.zero,
    Vec2 pivot = Vec2.zero,
  }) {
    List<Vec2> muovi(List<Vec2> punti) => [
          for (final p in punti) p.ruotato(rotazione, pivot) + traslazione,
        ];
    return GeometriaProfilo(
      mezzeria: muovi(mezzeria),
      contornoA: muovi(contornoA),
      contornoB: muovi(contornoB),
      archi: [
        for (final a in archi)
          ArcoPiega(
            indicePiega: a.indicePiega,
            centro: a.centro.ruotato(rotazione, pivot) + traslazione,
            raggioMezzeria: a.raggioMezzeria,
            rotazione: a.rotazione,
            indiceInizio: a.indiceInizio,
            indiceFine: a.indiceFine,
          ),
      ],
      spessore: spessore,
    );
  }

  @override
  String toString() =>
      'GeometriaProfilo(${mezzeria.length} punti, ${archi.length} archi)';
}

/// Costruisce la sezione del pezzo a partire dal profilo e dai risultati di
/// piega.
abstract final class CostruttoreGeometria {
  /// Quanti segmenti usare per approssimare ogni arco.
  static const int segmentiArcoPredefiniti = 14;

  /// Costruisce la geometria.
  ///
  /// [trattiPiani] sono i tratti rettilinei dello sviluppo (tangente a
  /// tangente): li fornisce `CalcoloSviluppo`.
  ///
  /// [angoliCorrenti] permette di mostrare una piega a metà corsa: per ogni
  /// indice contiene l'angolo formato in quel momento (180 = ancora piatta).
  /// Quando manca, ogni piega è al suo angolo finale.
  ///
  /// [ribaltato] specchia il pezzo, come quando l'operatore lo gira fra le mani.
  static GeometriaProfilo costruisci({
    required ProfiloLamiera profilo,
    required List<double> trattiPiani,
    required List<RisultatoPiega> pieghe,
    Map<int, double>? angoliCorrenti,
    bool ribaltato = false,
    int segmentiArco = segmentiArcoPredefiniti,
  }) {
    final spessore = profilo.spessore;
    final semiSpessore = spessore / 2;

    final mezzeria = <Vec2>[];
    final normaliSinistre = <Vec2>[];
    final archi = <ArcoPiega>[];

    var posizione = Vec2.zero;
    var direzione = 0.0;

    Vec2 versore(double angolo) => Vec2(math.cos(angolo), math.sin(angolo));

    for (var j = 0; j < trattiPiani.length; j++) {
      // --- tratto rettilineo ---------------------------------------------
      final avanti = versore(direzione);
      final normale = avanti.perpendicolare;
      mezzeria.add(posizione);
      normaliSinistre.add(normale);
      posizione = posizione + avanti * math.max(trattiPiani[j], 0);
      mezzeria.add(posizione);
      normaliSinistre.add(normale);

      if (j >= pieghe.length) continue;

      // --- arco di piega ---------------------------------------------------
      final piegaProfilo = profilo.pieghe[j];
      final angoloFormato =
          angoliCorrenti?[j] ?? piegaProfilo.angoloFormato;
      final rotazione = gradiInRadianti(180 - angoloFormato);
      final segno = piegaProfilo.verso.segno;
      final raggioMezzeria = pieghe[j].raggioInterno + semiSpessore;

      final centro = posizione + normale * (segno * raggioMezzeria);

      // Piega ancora piatta: nessun arco da campionare, ma il centro va
      // calcolato lo stesso perché è lui a definire la bisettrice con cui il
      // pezzo verrà posato sulla cava.
      if (rotazione.abs() < 1e-9 || raggioMezzeria <= 0) {
        archi.add(ArcoPiega(
          indicePiega: j,
          centro: centro,
          raggioMezzeria: raggioMezzeria,
          rotazione: 0,
          indiceInizio: mezzeria.length - 1,
          indiceFine: mezzeria.length - 1,
        ));
        continue;
      }

      final angoloIniziale = (posizione - centro).angolo;
      final spazzata = segno * rotazione;
      final indiceInizio = mezzeria.length - 1;

      for (var s = 1; s <= segmentiArco; s++) {
        final a = angoloIniziale + spazzata * s / segmentiArco;
        final punto = centro + Vec2(math.cos(a), math.sin(a)) * raggioMezzeria;
        final tangente = Vec2(-math.sin(a), math.cos(a)) * segno;
        mezzeria.add(punto);
        normaliSinistre.add(tangente.perpendicolare);
      }

      archi.add(ArcoPiega(
        indicePiega: j,
        centro: centro,
        raggioMezzeria: raggioMezzeria,
        rotazione: spazzata,
        indiceInizio: indiceInizio,
        indiceFine: mezzeria.length - 1,
      ));

      posizione = mezzeria.last;
      direzione += spazzata;
    }

    var geometria = GeometriaProfilo(
      mezzeria: mezzeria,
      contornoA: [
        for (var i = 0; i < mezzeria.length; i++)
          mezzeria[i] + normaliSinistre[i] * semiSpessore,
      ],
      contornoB: [
        for (var i = 0; i < mezzeria.length; i++)
          mezzeria[i] - normaliSinistre[i] * semiSpessore,
      ],
      archi: archi,
      spessore: spessore,
    );

    if (ribaltato) geometria = _specchia(geometria);
    return geometria;
  }

  static GeometriaProfilo _specchia(GeometriaProfilo g) {
    List<Vec2> rifletti(List<Vec2> punti) =>
        [for (final p in punti) p.specchiatoSuY];
    return GeometriaProfilo(
      // Specchiando, il lato sinistro del percorso diventa il destro.
      mezzeria: rifletti(g.mezzeria),
      contornoA: rifletti(g.contornoB),
      contornoB: rifletti(g.contornoA),
      archi: [
        for (final a in g.archi)
          ArcoPiega(
            indicePiega: a.indicePiega,
            centro: a.centro.specchiatoSuY,
            raggioMezzeria: a.raggioMezzeria,
            rotazione: -a.rotazione,
            indiceInizio: a.indiceInizio,
            indiceFine: a.indiceFine,
          ),
      ],
      spessore: g.spessore,
    );
  }
}
