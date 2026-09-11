import 'dart:math' as math;

import '../diagnostica/avvertimento.dart';
import '../formato/formato_numero.dart';
import '../piega/calcolo_piega.dart';
import '../profilo/profilo_lamiera.dart';
import '../sviluppo/calcolo_sviluppo.dart';
import '../utensili/utensili.dart';
import 'collisioni.dart';
import 'lato_minimo.dart';
import 'posizionatore.dart';

/// Quanto pesa ciascuna scomodità nella scelta della sequenza.
class PesiSequenza {
  /// Cambiare utensile fra due pieghe consecutive.
  final double cambioUtensile;

  /// Girare il pezzo fra le mani.
  final double ribaltamento;

  /// Ogni millimetro di gioco sotto quello desiderato.
  final double giocoScarso;

  /// Ogni millimetro di lembo sotto il minimo piegabile.
  final double latoCorto;

  /// Penalità applicata a un passo che collide, per poter comunque mostrare la
  /// sequenza "meno peggio" e far vedere dove si rompe.
  final double collisione;

  const PesiSequenza({
    this.cambioUtensile = 10,
    this.ribaltamento = 6,
    this.giocoScarso = 2,
    this.latoCorto = 8,
    this.collisione = 1000,
  });
}

/// Parametri del motore di sequenza.
class ParametriSequenza {
  /// Gioco sotto il quale si parla di collisione.
  final double giocoMinimo;

  /// Gioco che si vorrebbe avere: sotto questo si penalizza, senza vietare.
  final double giocoDesiderato;

  final int campioniCorsa;

  /// Quante sequenze restituire.
  final int maxSequenzeRestituite;

  /// Larghezza del fascio di ricerca.
  final int larghezzaBeam;

  /// Prova anche il pezzo ribaltato quando nel verso naturale collide.
  final bool provaRibaltamento;

  /// Prova un collo d'oca quando il coltello assegnato collide.
  final bool provaColloDoca;

  final PesiSequenza pesi;
  final ParametriLatoMinimo latoMinimo;

  const ParametriSequenza({
    this.giocoMinimo = RilevatoreCollisioni.giocoMinimoPredefinito,
    this.giocoDesiderato = 2.0,
    this.campioniCorsa = RilevatoreCollisioni.campioniCorsaPredefiniti,
    this.maxSequenzeRestituite = 5,
    this.larghezzaBeam = 200,
    this.provaRibaltamento = true,
    this.provaColloDoca = true,
    this.pesi = const PesiSequenza(),
    this.latoMinimo = const ParametriLatoMinimo(),
  });
}

/// Un passo della sequenza: una piega, con l'attrezzatura e il suo esito.
class PassoSequenza {
  final int indicePiega;
  final String idPunzone;
  final String idMatrice;
  final bool ribaltato;

  /// Le pieghe già formate quando si arriva a questo passo: serve a ricostruire
  /// l'anteprima senza rieseguire la ricerca.
  final Set<int> giaPiegate;

  final EsitoCollisione collisione;
  final EsitoLatoMinimo latoMinimoSinistro;
  final EsitoLatoMinimo latoMinimoDestro;

  /// Quanto scende il pezzo dentro la cava a fondo corsa.
  final double penetrazione;

  const PassoSequenza({
    required this.indicePiega,
    required this.idPunzone,
    required this.idMatrice,
    required this.ribaltato,
    required this.giaPiegate,
    required this.collisione,
    required this.latoMinimoSinistro,
    required this.latoMinimoDestro,
    required this.penetrazione,
  });

  bool get fattibile =>
      !collisione.collide &&
      latoMinimoSinistro.ammissibile &&
      latoMinimoDestro.ammissibile;

  /// Il lembo più critico dei due.
  EsitoLatoMinimo get latoPeggiore =>
      latoMinimoSinistro.margine <= latoMinimoDestro.margine
          ? latoMinimoSinistro
          : latoMinimoDestro;

  @override
  String toString() =>
      'Piega ${indicePiega + 1}${ribaltato ? " (ribaltato)" : ""}: '
      '${fattibile ? "ok" : "problema"}';
}

/// Una sequenza completa proposta.
///
/// Si chiama *proposta*, mai *verificata*: il controllo è sulla sezione, e
/// quello che non vede è elencato in [RilevatoreCollisioni.limitiNoti].
class SequenzaCandidata {
  final List<PassoSequenza> passi;
  final double costo;

  const SequenzaCandidata({required this.passi, required this.costo});

  bool get fattibile => passi.every((p) => p.fattibile);

  int get cambiUtensile {
    var conta = 0;
    for (var i = 1; i < passi.length; i++) {
      if (passi[i].idPunzone != passi[i - 1].idPunzone ||
          passi[i].idMatrice != passi[i - 1].idMatrice) {
        conta++;
      }
    }
    return conta;
  }

  int get ribaltamenti {
    var conta = 0;
    for (var i = 0; i < passi.length; i++) {
      final precedente = i == 0 ? false : passi[i - 1].ribaltato;
      if (passi[i].ribaltato != precedente) conta++;
    }
    return conta;
  }

  bool get richiedeColloDoca => passi.any((p) => p.idPunzone.contains('collo'));

  /// L'ordine delle pieghe, numerate da 1 come le legge l'operatore.
  List<int> get ordine => [for (final p in passi) p.indicePiega + 1];

  @override
  String toString() => 'Sequenza ${ordine.join(" → ")} '
      '(costo ${costo.toStringAsFixed(1)}${fattibile ? "" : ", non fattibile"})';
}

/// L'esito della ricerca.
class RisultatoSequenza {
  final List<SequenzaCandidata> sequenze;
  final List<Avvertimento> avvertimenti;

  /// Vero se la ricerca ha esplorato tutto lo spazio senza potare per ampiezza.
  final bool esaustiva;

  /// Quanti stati sono stati valutati: utile per capire se vale la pena
  /// allargare il fascio.
  final int statiValutati;

  const RisultatoSequenza({
    required this.sequenze,
    required this.avvertimenti,
    required this.esaustiva,
    this.statiValutati = 0,
  });

  SequenzaCandidata? get migliore =>
      sequenze.isEmpty ? null : sequenze.first;

  bool get haSequenzaFattibile => sequenze.any((s) => s.fattibile);
}

class _Parziale {
  final int maschera;
  final List<PassoSequenza> passi;
  final double costo;
  final bool fattibile;

  const _Parziale({
    required this.maschera,
    required this.passi,
    required this.costo,
    required this.fattibile,
  });
}

/// Il motore che propone l'ordine delle pieghe.
///
/// Cerca con un fascio sui sottoinsiemi di pieghe già fatte invece che sulle
/// permutazioni: la fattibilità di una piega dipende da **quali** pieghe sono
/// già state fatte, non dall'ordine in cui sono state fatte, e questo riduce
/// lo spazio da n! a n·2ⁿ stati, tutti memoizzati.
abstract final class MotoreSequenza {
  static RisultatoSequenza calcola(
    ProfiloLamiera profilo,
    Inventario inventario, {
    ParametriSequenza parametri = const ParametriSequenza(),
  }) {
    final avvertimenti = <Avvertimento>[];
    final sviluppo = CalcoloSviluppo.calcola(profilo, inventario);

    if (!sviluppo.eAttendibile) {
      return RisultatoSequenza(
        sequenze: const [],
        avvertimenti: [
          ...sviluppo.avvertimenti,
          const Avvertimento.errore(
            CodiceAvvertimento.nessunaSequenzaFattibile,
            'Senza uno sviluppo attendibile non si può proporre una sequenza.',
          ),
        ],
        esaustiva: false,
      );
    }

    final numero = profilo.pieghe.length;
    if (numero == 0) {
      return const RisultatoSequenza(
        sequenze: [],
        avvertimenti: [],
        esaustiva: true,
      );
    }

    final trattiPiani = sviluppo.trattiPiani;
    final pieghe = sviluppo.pieghe;

    final memoria = <String, PassoSequenza?>{};
    var statiValutati = 0;
    var esaustiva = true;

    PassoSequenza? valuta(
      int indicePiega,
      int maschera,
      String idPunzone,
      String idMatrice,
      bool ribaltato,
    ) {
      final chiave = '$indicePiega|$maschera|$idPunzone|$idMatrice|$ribaltato';
      if (memoria.containsKey(chiave)) return memoria[chiave];
      statiValutati++;

      final punzone = inventario.punzonePerId(idPunzone);
      final matrice = inventario.matricePerId(idMatrice);
      if (punzone == null || matrice == null) {
        memoria[chiave] = null;
        return null;
      }

      final giaPiegate = _daMaschera(maschera, numero);

      final collisione = RilevatoreCollisioni.verificaPasso(
        profilo: profilo,
        trattiPiani: trattiPiani,
        pieghe: pieghe,
        punzone: punzone,
        matrice: matrice,
        indicePiega: indicePiega,
        giaPiegate: giaPiegate,
        ribaltato: ribaltato,
        giocoMinimo: parametri.giocoMinimo,
        campioniCorsa: parametri.campioniCorsa,
      );

      final (lembiSinistro, lembiDestro) = _lembiEffettivi(
        indicePiega: indicePiega,
        giaPiegate: giaPiegate,
        trattiPiani: trattiPiani,
        pieghe: pieghe,
      );
      final angolo = profilo.pieghe[indicePiega].angoloFormato;
      final sinistro = LatoMinimo.verifica(
        lunghezzaLato: lembiSinistro,
        matrice: matrice,
        angoloFormato: angolo,
        spessore: profilo.spessore,
        parametri: parametri.latoMinimo,
      );
      final destro = LatoMinimo.verifica(
        lunghezzaLato: lembiDestro,
        matrice: matrice,
        angoloFormato: angolo,
        spessore: profilo.spessore,
        parametri: parametri.latoMinimo,
      );

      final passo = PassoSequenza(
        indicePiega: indicePiega,
        idPunzone: idPunzone,
        idMatrice: idMatrice,
        ribaltato: ribaltato,
        giaPiegate: giaPiegate,
        collisione: collisione,
        latoMinimoSinistro: sinistro,
        latoMinimoDestro: destro,
        penetrazione: PosizionatorePezzo.penetrazione(
          aperturaV: matrice.aperturaV,
          angoloIncluso: angolo,
          raggioEsterno: pieghe[indicePiega].raggioInterno + profilo.spessore,
        ),
      );
      memoria[chiave] = passo;
      return passo;
    }

    // --- ricerca a fascio sui sottoinsiemi ---------------------------------
    var fascio = <_Parziale>[
      const _Parziale(maschera: 0, passi: [], costo: 0, fattibile: true),
    ];

    for (var livello = 0; livello < numero; livello++) {
      final successivi = <_Parziale>[];

      for (final parziale in fascio) {
        for (var j = 0; j < numero; j++) {
          if (parziale.maschera & (1 << j) != 0) continue;

          final candidati = _punzoniCandidati(
            profilo: profilo,
            inventario: inventario,
            indicePiega: j,
            parametri: parametri,
          );
          final idMatrice = profilo.idMatricePer(j);
          if (idMatrice == null) continue;

          PassoSequenza? migliore;
          for (final idPunzone in candidati) {
            for (final ribaltato in parametri.provaRibaltamento
                ? const [false, true]
                : const [false]) {
              final passo = valuta(j, parziale.maschera, idPunzone, idMatrice,
                  ribaltato);
              if (passo == null) continue;
              if (passo.fattibile) {
                migliore = passo;
                break;
              }
              migliore ??= passo;
            }
            if (migliore != null && migliore.fattibile) break;
          }
          if (migliore == null) continue;

          final costoPasso = _costoPasso(
            passo: migliore,
            precedente: parziale.passi.isEmpty ? null : parziale.passi.last,
            parametri: parametri,
          );

          successivi.add(_Parziale(
            maschera: parziale.maschera | (1 << j),
            passi: [...parziale.passi, migliore],
            costo: parziale.costo + costoPasso,
            fattibile: parziale.fattibile && migliore.fattibile,
          ));
        }
      }

      if (successivi.isEmpty) break;

      successivi.sort((a, b) {
        if (a.fattibile != b.fattibile) return a.fattibile ? -1 : 1;
        return a.costo.compareTo(b.costo);
      });

      if (successivi.length > parametri.larghezzaBeam) {
        esaustiva = false;
        fascio = successivi.sublist(0, parametri.larghezzaBeam);
      } else {
        fascio = successivi;
      }
    }

    final complete = fascio.where((p) => p.passi.length == numero).toList();
    if (complete.isEmpty) {
      return RisultatoSequenza(
        sequenze: const [],
        avvertimenti: [
          ...avvertimenti,
          const Avvertimento.errore(
            CodiceAvvertimento.nessunaSequenzaFattibile,
            'Non è stata trovata nessuna sequenza completa con gli utensili '
            'selezionati. Prova con una cava diversa o con un collo d\'oca.',
          ),
        ],
        esaustiva: esaustiva,
        statiValutati: statiValutati,
      );
    }

    final sequenze = [
      for (final p in complete)
        SequenzaCandidata(passi: p.passi, costo: p.costo),
    ];
    sequenze.sort((a, b) {
      if (a.fattibile != b.fattibile) return a.fattibile ? -1 : 1;
      return a.costo.compareTo(b.costo);
    });

    final selezionate =
        sequenze.take(parametri.maxSequenzeRestituite).toList();

    if (!selezionate.any((s) => s.fattibile)) {
      avvertimenti.add(const Avvertimento.errore(
        CodiceAvvertimento.nessunaSequenzaFattibile,
        'Nessuna sequenza risulta eseguibile: ogni ordine incontra una '
        'collisione o un lembo troppo corto. Le proposte qui sotto mostrano '
        'dove si blocca.',
      ));
    }

    if (!esaustiva) {
      avvertimenti.add(Avvertimento.informazione(
        CodiceAvvertimento.ricercaLimitata,
        'Con $numero pieghe la ricerca è stata limitata alle '
        '${parametri.larghezzaBeam} combinazioni più promettenti per ogni '
        'passo: potrebbero esistere ordini validi non elencati.',
      ));
    }

    for (final passo in selezionate.first.passi) {
      if (passo.collisione.collide && passo.collisione.tipo != null) {
        avvertimenti.add(Avvertimento.attenzione(
          _codicePer(passo.collisione.tipo!),
          'Piega ${passo.indicePiega + 1}: il pezzo tocca '
          '${passo.collisione.tipo!.etichetta} a '
          '${FormatoNumero.gradi(passo.collisione.angoloCritico, decimali: 0)} '
          'di angolo.',
          indicePiega: passo.indicePiega,
        ));
      }
      final peggiore = passo.latoPeggiore;
      if (!peggiore.ammissibile) {
        final matrice = inventario.matricePerId(passo.idMatrice);
        if (matrice != null) {
          final a = LatoMinimo.avvertimento(
            esito: peggiore,
            matrice: matrice,
            indicePiega: passo.indicePiega,
          );
          if (a != null) avvertimenti.add(a);
        }
      }
    }

    return RisultatoSequenza(
      sequenze: selezionate,
      avvertimenti: avvertimenti,
      esaustiva: esaustiva,
      statiValutati: statiValutati,
    );
  }

  /// I coltelli da provare per una piega: prima quello assegnato, poi i colli
  /// d'oca, che sono la risposta ai profili a Z e alle pieghe di ritorno.
  static List<String> _punzoniCandidati({
    required ProfiloLamiera profilo,
    required Inventario inventario,
    required int indicePiega,
    required ParametriSequenza parametri,
  }) {
    final assegnato = profilo.idPunzonePer(indicePiega);
    final candidati = <String>[
      if (assegnato != null) assegnato,
    ];
    if (parametri.provaColloDoca) {
      for (final p in inventario.punzoni) {
        if (p.eColloDoca && !candidati.contains(p.id)) candidati.add(p.id);
      }
    }
    if (candidati.isEmpty && inventario.punzoni.isNotEmpty) {
      candidati.add(inventario.punzoniOrdinati.first.id);
    }
    return candidati;
  }

  /// Lunghezza del lembo che appoggia sulla cava, a sinistra e a destra della
  /// piega, misurata **dalla linea di piega** verso l'esterno.
  ///
  /// Due cose che è facile sbagliare, e che cambiano il risultato:
  ///
  /// - metà dell'arco appartiene a ciascun lembo, quindi va contata: senza,
  ///   un lembo corto risulta ancora più corto di quello che è;
  /// - il lembo non finisce alla piega adiacente se quella non è ancora stata
  ///   fatta — finché la lamiera è dritta, il materiale oltre continua ad
  ///   appoggiare sulla cava e fa lembo a tutti gli effetti.
  static (double, double) _lembiEffettivi({
    required int indicePiega,
    required Set<int> giaPiegate,
    required List<double> trattiPiani,
    required List<RisultatoPiega> pieghe,
  }) {
    final mezzoArco = pieghe[indicePiega].ba / 2;

    var sinistro = mezzoArco + trattiPiani[indicePiega];
    for (var k = indicePiega - 1; k >= 0; k--) {
      if (giaPiegate.contains(k)) break;
      sinistro += pieghe[k].ba + trattiPiani[k];
    }

    var destro = mezzoArco + trattiPiani[indicePiega + 1];
    for (var k = indicePiega + 1; k < pieghe.length; k++) {
      if (giaPiegate.contains(k)) break;
      destro += pieghe[k].ba + trattiPiani[k + 1];
    }

    return (sinistro, destro);
  }

  static double _costoPasso({
    required PassoSequenza passo,
    required PassoSequenza? precedente,
    required ParametriSequenza parametri,
  }) {
    final pesi = parametri.pesi;
    var costo = 0.0;

    if (precedente != null) {
      if (precedente.idPunzone != passo.idPunzone ||
          precedente.idMatrice != passo.idMatrice) {
        costo += pesi.cambioUtensile;
      }
      if (precedente.ribaltato != passo.ribaltato) costo += pesi.ribaltamento;
    } else if (passo.ribaltato) {
      costo += pesi.ribaltamento;
    }

    // Solo il gioco dal coltello entra nel costo: quello dalla cava è appoggio
    // normale, non una distanza da massimizzare.
    final gioco = passo.collisione.giocoPunzone;
    if (gioco.isFinite && gioco < parametri.giocoDesiderato) {
      costo += pesi.giocoScarso * (parametri.giocoDesiderato - gioco);
    }

    for (final lato in [passo.latoMinimoSinistro, passo.latoMinimoDestro]) {
      if (!lato.ammissibile) costo += pesi.latoCorto * lato.margine.abs();
    }

    if (passo.collisione.collide) costo += pesi.collisione;

    return costo;
  }

  static Set<int> _daMaschera(int maschera, int numero) {
    final insieme = <int>{};
    for (var i = 0; i < numero; i++) {
      if (maschera & (1 << i) != 0) insieme.add(i);
    }
    return insieme;
  }

  static String _codicePer(TipoCollisione tipo) => switch (tipo) {
        TipoCollisione.punzone => CodiceAvvertimento.collisionePunzone,
        TipoCollisione.matrice => CodiceAvvertimento.collisioneMatrice,
        TipoCollisione.banco => CodiceAvvertimento.collisioneBanco,
        TipoCollisione.altezzaUtensile =>
          CodiceAvvertimento.altezzaUtensileInsufficiente,
      };

  /// Quante pieghe al massimo prima che la ricerca debba potare.
  static int sogliaEsaustiva(int larghezzaBeam) =>
      (math.log(larghezzaBeam) / math.ln2).floor() + 2;
}
