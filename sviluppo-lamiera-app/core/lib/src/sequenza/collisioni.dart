import 'dart:math' as math;

import '../geometria/intersezione.dart';
import '../geometria/poligono.dart';
import '../geometria/vec2.dart';
import '../piega/calcolo_piega.dart';
import '../profilo/profilo_lamiera.dart';
import '../utensili/utensili.dart';
import 'posizionatore.dart';

/// Contro cosa va a sbattere il pezzo.
enum TipoCollisione {
  punzone,
  matrice,
  banco,
  altezzaUtensile;

  String get etichetta => switch (this) {
        TipoCollisione.punzone => 'il coltello',
        TipoCollisione.matrice => 'la cava',
        TipoCollisione.banco => 'il banco',
        TipoCollisione.altezzaUtensile => "l'altezza dell'utensile",
      };
}

/// Esito del controllo di interferenza per un passo di piega.
class EsitoCollisione {
  final bool collide;

  /// Gioco minimo dal coltello lungo tutta la corsa, mm.
  final double giocoPunzone;

  /// Compenetrazione con la cava, col segno: zero quando il pezzo si limita ad
  /// appoggiarci sopra, negativa quando ci entra dentro.
  final double giocoMatrice;

  /// Angolo della corsa al quale il gioco è minimo.
  final double angoloCritico;

  final Vec2? puntoCritico;
  final TipoCollisione? tipo;

  const EsitoCollisione({
    required this.collide,
    required this.giocoPunzone,
    required this.giocoMatrice,
    required this.angoloCritico,
    this.puntoCritico,
    this.tipo,
  });

  static const EsitoCollisione libero = EsitoCollisione(
    collide: false,
    giocoPunzone: double.infinity,
    giocoMatrice: double.infinity,
    angoloCritico: 180,
  );

  /// Il valore peggiore fra i due, per un colpo d'occhio complessivo.
  double get giocoMinimo => math.min(giocoPunzone, giocoMatrice);

  @override
  String toString() => collide
      ? 'collisione con ${tipo?.etichetta ?? "?"} a '
          '${angoloCritico.toStringAsFixed(0)}°'
      : 'libero (gioco dal coltello ${giocoPunzone.toStringAsFixed(1)} mm)';
}

/// Il rilevatore di interferenze fra il pezzo e gli utensili.
///
/// Lavora **sulla sola sezione trasversale**: vede tutto quello che succede
/// nel piano che si guarda stando di lato alla piegatrice, e non vede nulla di
/// quello che succede fuori da quel piano. I limiti sono elencati in
/// [limitiNoti] e vanno mostrati all'operatore, non nascosti nella
/// documentazione.
abstract final class RilevatoreCollisioni {
  /// Gioco minimo accettabile fra pezzo e utensile, mm.
  static const double giocoMinimoPredefinito = 0.5;

  /// Quanto il pezzo può compenetrare la cava prima che si parli di urto.
  ///
  /// Non è zero perché la lamiera appoggia davvero sulle spalle: serve un
  /// margine che distingua l'appoggio normale dall'entrare nel corpo della
  /// matrice.
  static const double tolleranzaAppoggio = 0.2;

  /// Quanti istanti della corsa campionare fra lamiera piatta e angolo finale.
  ///
  /// Serve perché una sequenza può essere libera a fondo corsa e interferire a
  /// metà: controllare solo la posizione finale lascia passare proprio le
  /// collisioni che rovinano il pezzo.
  static const int campioniCorsaPredefiniti = 7;

  /// Quello che questo controllo **non** vede. Da mostrare nell'app.
  static const List<String> limitiNoti = [
    'Controlla solo la sezione: angoli di scatola, pareti laterali e pieghe '
        'non parallele non sono rappresentati.',
    'Non conosce telaio, spalle, portautensili e spezzoni di utensile.',
    'Non verifica i ditali della battuta né gli assi R e Z.',
    'Non tiene conto del peso del pezzo, della flessione dei lembi lunghi né '
        'di come lo regge l\'operatore.',
    'Non calcola il ritorno elastico: gli angoli sono quelli a fondo corsa.',
  ];

  /// Verifica un singolo passo di piega lungo tutta la corsa.
  static EsitoCollisione verificaPasso({
    required ProfiloLamiera profilo,
    required List<double> trattiPiani,
    required List<RisultatoPiega> pieghe,
    required Punzone punzone,
    required Matrice matrice,
    required int indicePiega,
    required Set<int> giaPiegate,
    bool ribaltato = false,
    double giocoMinimo = giocoMinimoPredefinito,
    int campioniCorsa = campioniCorsaPredefiniti,
  }) {
    final angoloFinale = profilo.pieghe[indicePiega].angoloFormato;
    final raggioInterno = pieghe[indicePiega].raggioInterno;

    var peggiorePunzone = double.infinity;
    var peggioreMatrice = double.infinity;
    var angoloCritico = angoloFinale;
    Vec2? puntoCritico;
    TipoCollisione? tipo;
    var collide = false;

    final passi = math.max(campioniCorsa, 2);
    for (var s = 0; s < passi; s++) {
      // Dalla lamiera piatta fino all'angolo finale.
      final angolo = 180 - (180 - angoloFinale) * s / (passi - 1);

      final pezzo = PosizionatorePezzo.posa(
        profilo: profilo,
        trattiPiani: trattiPiani,
        pieghe: pieghe,
        matrice: matrice,
        indicePiega: indicePiega,
        giaPiegate: giaPiegate,
        angoloIncluso: angolo,
        ribaltato: ribaltato,
      );

      final contorno = pezzo.contornoChiuso;
      if (contorno.length < 3) continue;

      // --- coltello -------------------------------------------------------
      final quotaPunta = PosizionatorePezzo.quotaPuntaPunzone(
        aperturaV: matrice.aperturaV,
        angoloIncluso: angolo,
        raggioInterno: raggioInterno,
        raggioPunta: punzone.raggioPunta,
        spessore: profilo.spessore,
      );
      if (quotaPunta.isFinite) {
        final sagomaPunzone = punzone.sagoma.traslato(Vec2(0, quotaPunta));
        final esito = giocoPolilineaPoligono(
          contorno,
          sagomaPunzone,
          indiciEsclusi: _zonaDiContatto(
            contorno,
            semiLarghezza: matrice.aperturaV / 2 + matrice.raggioSpalla + 1,
          ),
        );
        if (esito.gioco < peggiorePunzone) {
          peggiorePunzone = esito.gioco;
          if (esito.gioco < giocoMinimo) {
            angoloCritico = angolo;
            puntoCritico = esito.puntoCritico;
            tipo = TipoCollisione.punzone;
            collide = true;
          }
        }
      }

      // --- cava -------------------------------------------------------------
      // Qui si misura la compenetrazione, non la distanza: la lamiera appoggia
      // sulla cava per tutta la sua lunghezza, e quell'appoggio è il modo
      // normale di lavorare, non un urto. Diventa un problema solo quando il
      // pezzo entra davvero nel corpo della matrice.
      final dentroMatrice = penetrazioneMassima(
        contorno,
        matrice.sagoma,
        indiciEsclusi: _zonaDiContatto(
          contorno,
          semiLarghezza: matrice.aperturaV / 2 + matrice.raggioSpalla + 1,
        ),
      );
      final giocoMatrice = -dentroMatrice;
      if (giocoMatrice < peggioreMatrice) {
        peggioreMatrice = giocoMatrice;
        if (dentroMatrice > tolleranzaAppoggio && !collide) {
          angoloCritico = angolo;
          tipo = TipoCollisione.matrice;
          collide = true;
        }
      }

      // --- banco ----------------------------------------------------------
      if (pezzo.quotaMinima < -matrice.altezza) {
        if (!collide) {
          angoloCritico = angolo;
          tipo = TipoCollisione.banco;
          collide = true;
        }
      }

      // --- altezza utile del coltello --------------------------------------
      if (pezzo.altezzaMassima > punzone.altezza) {
        if (!collide) {
          angoloCritico = angolo;
          tipo = TipoCollisione.altezzaUtensile;
          collide = true;
        }
      }
    }

    return EsitoCollisione(
      collide: collide,
      giocoPunzone: peggiorePunzone,
      giocoMatrice: peggioreMatrice,
      angoloCritico: angoloCritico,
      puntoCritico: puntoCritico,
      tipo: tipo,
    );
  }

  /// Gli indici del contorno che stanno nella zona dove gli utensili devono
  /// toccare la lamiera. Senza questa esclusione ogni piega risulterebbe una
  /// collisione con sé stessa.
  static Set<int> _zonaDiContatto(
    List<Vec2> contorno, {
    required double semiLarghezza,
  }) {
    final esclusi = <int>{};
    for (var i = 0; i < contorno.length; i++) {
      if (contorno[i].x.abs() <= semiLarghezza) esclusi.add(i);
    }
    return esclusi;
  }

  /// Versione rapida per la potatura: guarda solo il fondo corsa.
  ///
  /// Costa un settimo del controllo completo ed elimina subito la maggior
  /// parte degli ordini impossibili; quelli che sopravvivono passano poi al
  /// controllo su tutta la corsa.
  static EsitoCollisione verificaFondoCorsa({
    required ProfiloLamiera profilo,
    required List<double> trattiPiani,
    required List<RisultatoPiega> pieghe,
    required Punzone punzone,
    required Matrice matrice,
    required int indicePiega,
    required Set<int> giaPiegate,
    bool ribaltato = false,
    double giocoMinimo = giocoMinimoPredefinito,
  }) {
    return verificaPasso(
      profilo: profilo,
      trattiPiani: trattiPiani,
      pieghe: pieghe,
      punzone: punzone,
      matrice: matrice,
      indicePiega: indicePiega,
      giaPiegate: giaPiegate,
      ribaltato: ribaltato,
      giocoMinimo: giocoMinimo,
      campioniCorsa: 2,
    );
  }

  /// Sagoma del coltello alla quota di corsa, per il disegno.
  static Poligono sagomaPunzonePosizionata({
    required Punzone punzone,
    required Matrice matrice,
    required double angoloIncluso,
    required double raggioInterno,
    required double spessore,
  }) {
    final quota = PosizionatorePezzo.quotaPuntaPunzone(
      aperturaV: matrice.aperturaV,
      angoloIncluso: angoloIncluso,
      raggioInterno: raggioInterno,
      raggioPunta: punzone.raggioPunta,
      spessore: spessore,
    );
    return quota.isFinite
        ? punzone.sagoma.traslato(Vec2(0, quota))
        : punzone.sagoma;
  }
}
