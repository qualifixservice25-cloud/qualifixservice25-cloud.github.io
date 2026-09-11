import '../diagnostica/avvertimento.dart';
import '../formato/formato_numero.dart';
import '../piega/calcolo_piega.dart';
import '../profilo/profilo_lamiera.dart';
import '../utensili/utensili.dart';

/// Una riga della tabella di sviluppo: un tratto del pezzo, com'è stato
/// quotato e com'è disteso.
class RigaSviluppo {
  final String etichetta;

  /// La misura come l'ha scritta l'operatore.
  final double quotaInserita;

  /// Il tratto piano corrispondente sullo sviluppo.
  final double quotaPiatta;

  /// Sporgenza tolta all'inizio del tratto (zero sul primo).
  final double sporgenzaIniziale;

  /// Sporgenza tolta alla fine del tratto (zero sull'ultimo).
  final double sporgenzaFinale;

  const RigaSviluppo({
    required this.etichetta,
    required this.quotaInserita,
    required this.quotaPiatta,
    this.sporgenzaIniziale = 0,
    this.sporgenzaFinale = 0,
  });

  @override
  String toString() =>
      '$etichetta: ${quotaInserita.toStringAsFixed(1)} → '
      '${quotaPiatta.toStringAsFixed(2)}';
}

/// L'esito completo del calcolo di sviluppo.
class RisultatoSviluppo {
  /// La lunghezza da tagliare. È il numero per cui esiste l'app.
  ///
  /// Non finito quando il calcolo non è attendibile: in quel caso fra gli
  /// [avvertimenti] c'è sempre un errore bloccante che ne spiega il motivo.
  final double lunghezzaTotale;

  final double sommaQuoteInserite;
  final double sommaAbbuoni;
  final double sommaDetrazioni;

  final List<RigaSviluppo> righe;
  final List<RisultatoPiega> pieghe;

  /// Ascisse delle linee di piega sullo sviluppo disteso, misurate dal bordo
  /// iniziale. Sono le righe che si tracciano davvero sul pezzo.
  final List<double> posizioniLineeDiPiega;

  final QuotaturaProfilo quotatura;
  final List<Avvertimento> avvertimenti;

  const RisultatoSviluppo({
    required this.lunghezzaTotale,
    required this.sommaQuoteInserite,
    required this.sommaAbbuoni,
    required this.sommaDetrazioni,
    required this.righe,
    required this.pieghe,
    required this.posizioniLineeDiPiega,
    required this.quotatura,
    required this.avvertimenti,
  });

  bool get eAttendibile =>
      lunghezzaTotale.isFinite && !avvertimenti.haErrori;

  /// I tratti piani, nell'ordine.
  List<double> get trattiPiani => [for (final r in righe) r.quotaPiatta];

  @override
  String toString() => 'RisultatoSviluppo(${lunghezzaTotale.toStringAsFixed(2)} mm)';
}

/// Il solutore dello sviluppo: da un profilo quotato alla lunghezza da
/// tagliare.
abstract final class CalcoloSviluppo {
  /// `L = Σ lati esterni − Σ BD`
  static double daQuoteEsterne(
    List<double> latiEsterni,
    List<RisultatoPiega> pieghe,
  ) {
    var somma = 0.0;
    for (final l in latiEsterni) {
      somma += l;
    }
    for (final p in pieghe) {
      somma -= p.bd;
    }
    return somma;
  }

  /// `L = Σ tratti piani + Σ BA`
  static double daQuoteInterne(
    List<double> trattiPiani,
    List<RisultatoPiega> pieghe,
  ) {
    var somma = 0.0;
    for (final t in trattiPiani) {
      somma += t;
    }
    for (final p in pieghe) {
      somma += p.ba;
    }
    return somma;
  }

  /// Converte le quote esterne nei tratti piani togliendo le sporgenze.
  ///
  /// Ogni piega toglie una sporgenza al tratto che la precede e una a quello
  /// che la segue; i due estremi del pezzo non hanno nulla da togliere da un
  /// lato.
  static List<double> esterneAInterne(
    List<double> esterne,
    List<RisultatoPiega> pieghe,
  ) {
    final risultato = <double>[];
    for (var j = 0; j < esterne.length; j++) {
      final prima = j > 0 ? pieghe[j - 1].ossb : 0.0;
      final dopo = j < pieghe.length ? pieghe[j].ossb : 0.0;
      risultato.add(esterne[j] - prima - dopo);
    }
    return risultato;
  }

  /// Il contrario: dai tratti piani alle quote esterne.
  static List<double> interneAEsterne(
    List<double> interne,
    List<RisultatoPiega> pieghe,
  ) {
    final risultato = <double>[];
    for (var j = 0; j < interne.length; j++) {
      final prima = j > 0 ? pieghe[j - 1].ossb : 0.0;
      final dopo = j < pieghe.length ? pieghe[j].ossb : 0.0;
      risultato.add(interne[j] + prima + dopo);
    }
    return risultato;
  }

  /// Ascisse delle linee di piega sullo sviluppo, al centro di ciascun arco.
  static List<double> posizioniLineeDiPiega(
    List<double> trattiPiani,
    List<RisultatoPiega> pieghe,
  ) {
    final posizioni = <double>[];
    var cursore = 0.0;
    for (var j = 0; j < pieghe.length; j++) {
      cursore += trattiPiani[j];
      posizioni.add(cursore + pieghe[j].ba / 2);
      cursore += pieghe[j].ba;
    }
    return posizioni;
  }

  /// Calcola lo sviluppo di un profilo usando le cave dell'inventario.
  ///
  /// Se una piega non ha una cava utilizzabile il calcolo **non** ripiega su
  /// un valore teorico: restituisce un risultato non attendibile con l'errore
  /// che lo spiega. Un numero plausibile ma inventato è il modo più veloce per
  /// mandare a scarto della lamiera.
  static RisultatoSviluppo calcola(
    ProfiloLamiera profilo,
    Inventario inventario,
  ) {
    final avvertimenti = <Avvertimento>[...profilo.valida(inventario)];

    if (avvertimenti.haErrori) {
      return _nonAttendibile(profilo, avvertimenti);
    }

    // --- una piega alla volta ----------------------------------------------
    final pieghe = <RisultatoPiega>[];
    for (var i = 0; i < profilo.pieghe.length; i++) {
      final matrice = inventario.matricePerId(profilo.idMatricePer(i));
      if (matrice == null) {
        avvertimenti.add(Avvertimento.errore(
          CodiceAvvertimento.nessunaCavaAdatta,
          'Piega ${i + 1}: cava non trovata in inventario.',
          indicePiega: i,
        ));
        return _nonAttendibile(profilo, avvertimenti);
      }
      final risultato = CalcoloPiega.calcola(ParametriPiega(
        spessore: profilo.spessore,
        angoloFormato: profilo.pieghe[i].angoloFormato,
        aperturaV: matrice.aperturaV,
        materiale: profilo.materiale,
      ));
      pieghe.add(risultato);
      for (final a in risultato.avvertimenti) {
        avvertimenti.add(Avvertimento(
          gravita: a.gravita,
          codice: a.codice,
          messaggio: 'Piega ${i + 1}: ${a.messaggio}',
          indicePiega: i,
        ));
      }
    }

    if (avvertimenti.haErrori) {
      return _nonAttendibile(profilo, avvertimenti);
    }

    // --- dai numeri scritti ai tratti piani --------------------------------
    final quoteInserite = [for (final t in profilo.tratti) t.lunghezza];
    final trattiPiani = profilo.quotatura == QuotaturaProfilo.esterna
        ? esterneAInterne(quoteInserite, pieghe)
        : quoteInserite;

    final righe = <RigaSviluppo>[];
    for (var j = 0; j < profilo.tratti.length; j++) {
      final prima = j > 0 ? pieghe[j - 1].ossb : 0.0;
      final dopo = j < pieghe.length ? pieghe[j].ossb : 0.0;
      righe.add(RigaSviluppo(
        etichetta: profilo.tratti[j].etichetta,
        quotaInserita: quoteInserite[j],
        quotaPiatta: trattiPiani[j],
        sporgenzaIniziale:
            profilo.quotatura == QuotaturaProfilo.esterna ? prima : 0,
        sporgenzaFinale:
            profilo.quotatura == QuotaturaProfilo.esterna ? dopo : 0,
      ));

      if (trattiPiani[j] < 0) {
        avvertimenti.add(Avvertimento.errore(
          CodiceAvvertimento.flangiaMinoreDiSetback,
          'Il tratto ${profilo.tratti[j].etichetta} '
          '(${FormatoNumero.mm(quoteInserite[j])}) è più corto delle sporgenze '
          'delle pieghe che lo delimitano: con questa cava la quota non è '
          'realizzabile. Serve una cava più stretta o un tratto più lungo.',
        ));
      }
    }

    if (avvertimenti.haErrori) {
      return _nonAttendibile(profilo, avvertimenti, pieghe: pieghe, righe: righe);
    }

    // --- il totale ---------------------------------------------------------
    final lunghezza = daQuoteInterne(trattiPiani, pieghe);

    var sommaQuote = 0.0;
    for (final q in quoteInserite) {
      sommaQuote += q;
    }
    var sommaAbbuoni = 0.0;
    var sommaDetrazioni = 0.0;
    for (final p in pieghe) {
      sommaAbbuoni += p.ba;
      sommaDetrazioni += p.bd;
    }

    if (!lunghezza.isFinite) {
      avvertimenti.add(const Avvertimento.errore(
        CodiceAvvertimento.ingressoNonValido,
        'Lo sviluppo non ha prodotto un numero valido: controlla i dati.',
      ));
    }

    return RisultatoSviluppo(
      lunghezzaTotale: lunghezza,
      sommaQuoteInserite: sommaQuote,
      sommaAbbuoni: sommaAbbuoni,
      sommaDetrazioni: sommaDetrazioni,
      righe: righe,
      pieghe: pieghe,
      posizioniLineeDiPiega: posizioniLineeDiPiega(trattiPiani, pieghe),
      quotatura: profilo.quotatura,
      avvertimenti: avvertimenti,
    );
  }

  static RisultatoSviluppo _nonAttendibile(
    ProfiloLamiera profilo,
    List<Avvertimento> avvertimenti, {
    List<RisultatoPiega> pieghe = const [],
    List<RigaSviluppo> righe = const [],
  }) {
    return RisultatoSviluppo(
      lunghezzaTotale: double.nan,
      sommaQuoteInserite: 0,
      sommaAbbuoni: 0,
      sommaDetrazioni: 0,
      righe: righe,
      pieghe: pieghe,
      posizioniLineeDiPiega: const [],
      quotatura: profilo.quotatura,
      avvertimenti: avvertimenti,
    );
  }
}
