/// Gravità di un avvertimento, dal più tenue al più grave.
enum GravitaAvvertimento {
  /// Informazione utile, nessuna azione richiesta.
  informazione,

  /// Il calcolo è valido ma qualcosa va verificato prima di piegare.
  attenzione,

  /// Il calcolo non è attendibile o la lavorazione non è eseguibile.
  errore,
}

/// Codici stabili degli avvertimenti. Stringhe costanti invece di un enum
/// perché finiscono nel JSON dei progetti salvati e devono sopravvivere alle
/// versioni dell'app.
abstract final class CodiceAvvertimento {
  static const latoMinimo = 'LATO_MINIMO';
  static const flangiaMinoreDiSetback = 'FLANGIA_MINORE_DI_OSSB';
  static const raggioSuSpessoreBasso = 'RI_SU_S_BASSO';
  static const cavaNonConsigliata = 'V_NON_CONSIGLIATA';
  static const cavaTroppoStretta = 'V_TROPPO_STRETTA';
  static const nessunaCavaAdatta = 'NESSUNA_CAVA_ADATTA';
  static const angoloFuoriRegime = 'ANGOLO_FUORI_REGIME';
  static const collisionePunzone = 'COLLISIONE_PUNZONE';
  static const collisioneMatrice = 'COLLISIONE_MATRICE';
  static const collisioneBanco = 'COLLISIONE_BANCO';
  static const altezzaUtensileInsufficiente = 'ALTEZZA_UTENSILE';
  static const ricercaLimitata = 'RICERCA_LIMITATA';
  static const nessunaSequenzaFattibile = 'NESSUNA_SEQUENZA';
  static const kTarato = 'K_TARATO';
  static const ritornoElasticoNonCalcolato = 'RITORNO_ELASTICO_ASSENTE';
  static const ingressoNonValido = 'INGRESSO_NON_VALIDO';
}

/// Un avvertimento rivolto all'operatore, sempre in italiano e orientato
/// all'azione: dice cosa non va **e** cosa fare.
class Avvertimento {
  final GravitaAvvertimento gravita;
  final String codice;
  final String messaggio;

  /// Indice della piega a cui si riferisce, se pertinente.
  final int? indicePiega;

  const Avvertimento({
    required this.gravita,
    required this.codice,
    required this.messaggio,
    this.indicePiega,
  });

  const Avvertimento.informazione(this.codice, this.messaggio,
      {this.indicePiega})
      : gravita = GravitaAvvertimento.informazione;

  const Avvertimento.attenzione(this.codice, this.messaggio, {this.indicePiega})
      : gravita = GravitaAvvertimento.attenzione;

  const Avvertimento.errore(this.codice, this.messaggio, {this.indicePiega})
      : gravita = GravitaAvvertimento.errore;

  bool get eBloccante => gravita == GravitaAvvertimento.errore;

  @override
  String toString() => '[${gravita.name}] $codice: $messaggio';
}

/// Estensioni di comodo su una lista di avvertimenti.
extension ElencoAvvertimenti on List<Avvertimento> {
  bool get haErrori => any((a) => a.eBloccante);

  List<Avvertimento> get ordinatiPerGravita {
    final copia = [...this];
    copia.sort((a, b) => b.gravita.index.compareTo(a.gravita.index));
    return copia;
  }
}
