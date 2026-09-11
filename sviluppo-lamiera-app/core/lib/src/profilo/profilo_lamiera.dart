import '../diagnostica/avvertimento.dart';
import '../formato/formato_numero.dart';
import '../materiali/materiale.dart';
import '../materiali/tabella_materiali.dart';
import '../utensili/selezione_matrice.dart';
import '../utensili/utensili.dart';

/// Verso della piega guardando il profilo da sinistra a destra.
enum VersoPiega {
  su,
  giu;

  String get etichetta => this == VersoPiega.su ? 'in su' : 'in giù';

  VersoPiega get opposto => this == VersoPiega.su ? VersoPiega.giu : VersoPiega.su;

  /// Segno da applicare alla rotazione nel piano della sezione.
  double get segno => this == VersoPiega.su ? 1.0 : -1.0;
}

/// Come sono state prese le quote sul disegno.
enum QuotaturaProfilo {
  /// Misure prese sul filo esterno: è il modo normale di quotare una scatola.
  esterna,

  /// Misure dei tratti piani, dalla tangente all'arco.
  interna;

  String get etichetta =>
      this == QuotaturaProfilo.esterna ? 'Quote esterne' : 'Quote interne';
}

/// Un tratto rettilineo del profilo.
class TrattoProfilo {
  /// Lettera mostrata sul disegno: A, B, C…
  final String etichetta;

  /// Lunghezza come l'ha scritta l'operatore, nel modo di quotatura scelto.
  final double lunghezza;

  const TrattoProfilo(this.etichetta, this.lunghezza);

  TrattoProfilo copiaCon({String? etichetta, double? lunghezza}) =>
      TrattoProfilo(etichetta ?? this.etichetta, lunghezza ?? this.lunghezza);

  Map<String, dynamic> aMappa() =>
      {'etichetta': etichetta, 'lunghezza': lunghezza};

  static TrattoProfilo daMappa(Map<String, dynamic> m) => TrattoProfilo(
        (m['etichetta'] as String?) ?? '?',
        (m['lunghezza'] as num).toDouble(),
      );

  @override
  String toString() => '$etichetta=${lunghezza.toStringAsFixed(1)}';
}

/// Una piega fra due tratti.
class PiegaProfilo {
  /// Angolo formato, quello che si legge sul pezzo. 90° = squadra.
  final double angoloFormato;

  final VersoPiega verso;

  /// Cava da usare per questa piega. Null significa "quella del profilo".
  final String? idMatrice;

  /// Coltello da usare. Null significa "quello del profilo".
  final String? idPunzone;

  const PiegaProfilo({
    this.angoloFormato = 90,
    this.verso = VersoPiega.su,
    this.idMatrice,
    this.idPunzone,
  });

  PiegaProfilo copiaCon({
    double? angoloFormato,
    VersoPiega? verso,
    String? idMatrice,
    String? idPunzone,
  }) {
    return PiegaProfilo(
      angoloFormato: angoloFormato ?? this.angoloFormato,
      verso: verso ?? this.verso,
      idMatrice: idMatrice ?? this.idMatrice,
      idPunzone: idPunzone ?? this.idPunzone,
    );
  }

  Map<String, dynamic> aMappa() => {
        'angoloFormato': angoloFormato,
        'verso': verso.name,
        if (idMatrice != null) 'idMatrice': idMatrice,
        if (idPunzone != null) 'idPunzone': idPunzone,
      };

  static PiegaProfilo daMappa(Map<String, dynamic> m) => PiegaProfilo(
        angoloFormato: (m['angoloFormato'] as num?)?.toDouble() ?? 90,
        verso: VersoPiega.values.firstWhere(
          (v) => v.name == m['verso'],
          orElse: () => VersoPiega.su,
        ),
        idMatrice: m['idMatrice'] as String?,
        idPunzone: m['idPunzone'] as String?,
      );

  @override
  String toString() => '${angoloFormato.toStringAsFixed(0)}° ${verso.name}';
}

/// Il pezzo da piegare: una catena di tratti separati da pieghe.
///
/// Un profilo ha **un solo** spessore e **un solo** materiale: è una lamiera,
/// non un assieme.
class ProfiloLamiera {
  final String nome;
  final double spessore;
  final Materiale materiale;
  final QuotaturaProfilo quotatura;

  /// Cava e coltello usati dove la singola piega non ne indica di propri.
  final String? idMatricePredefinita;
  final String? idPunzonePredefinito;

  final List<TrattoProfilo> tratti;
  final List<PiegaProfilo> pieghe;

  const ProfiloLamiera({
    this.nome = 'Nuovo pezzo',
    required this.spessore,
    this.materiale = TabellaMateriali.acciaioDolce,
    this.quotatura = QuotaturaProfilo.esterna,
    this.idMatricePredefinita,
    this.idPunzonePredefinito,
    required this.tratti,
    required this.pieghe,
  });

  /// Un profilo di partenza: squadretta 100 × 100 a 90°.
  static ProfiloLamiera esempio({double spessore = 2}) => ProfiloLamiera(
        nome: 'Squadretta',
        spessore: spessore,
        tratti: const [TrattoProfilo('A', 100), TrattoProfilo('B', 100)],
        pieghe: const [PiegaProfilo()],
      );

  int get numeroPieghe => pieghe.length;

  /// Vero se la catena è coerente: n tratti e n−1 pieghe.
  bool get haStrutturaValida =>
      tratti.length >= 2 && pieghe.length == tratti.length - 1;

  /// Cava effettiva della piega [indice], risolvendo il valore predefinito.
  String? idMatricePer(int indice) =>
      pieghe[indice].idMatrice ?? idMatricePredefinita;

  /// Coltello effettivo della piega [indice].
  String? idPunzonePer(int indice) =>
      pieghe[indice].idPunzone ?? idPunzonePredefinito;

  ProfiloLamiera copiaCon({
    String? nome,
    double? spessore,
    Materiale? materiale,
    QuotaturaProfilo? quotatura,
    String? idMatricePredefinita,
    String? idPunzonePredefinito,
    List<TrattoProfilo>? tratti,
    List<PiegaProfilo>? pieghe,
  }) {
    return ProfiloLamiera(
      nome: nome ?? this.nome,
      spessore: spessore ?? this.spessore,
      materiale: materiale ?? this.materiale,
      quotatura: quotatura ?? this.quotatura,
      idMatricePredefinita: idMatricePredefinita ?? this.idMatricePredefinita,
      idPunzonePredefinito: idPunzonePredefinito ?? this.idPunzonePredefinito,
      tratti: tratti ?? this.tratti,
      pieghe: pieghe ?? this.pieghe,
    );
  }

  /// Aggiunge un tratto in fondo, con la piega che lo collega al precedente.
  ProfiloLamiera conTrattoAggiunto({
    double lunghezza = 50,
    PiegaProfilo piega = const PiegaProfilo(),
  }) {
    final etichetta = _etichettaPer(tratti.length);
    return copiaCon(
      tratti: [...tratti, TrattoProfilo(etichetta, lunghezza)],
      pieghe: [...pieghe, piega],
    );
  }

  /// Toglie il tratto [indice] e la piega che lo accompagna, rinumerando.
  ProfiloLamiera senzaTratto(int indice) {
    if (tratti.length <= 2) return this;
    final nuoviTratti = [...tratti]..removeAt(indice);
    final nuovePieghe = [...pieghe];
    nuovePieghe.removeAt(indice == 0 ? 0 : indice - 1);
    return copiaCon(
      tratti: [
        for (var i = 0; i < nuoviTratti.length; i++)
          nuoviTratti[i].copiaCon(etichetta: _etichettaPer(i)),
      ],
      pieghe: nuovePieghe,
    );
  }

  /// Controlli che non dipendono dal calcolo: struttura, misure, utensili.
  List<Avvertimento> valida(Inventario inventario) {
    final avvertimenti = <Avvertimento>[];

    if (!haStrutturaValida) {
      avvertimenti.add(const Avvertimento.errore(
        CodiceAvvertimento.ingressoNonValido,
        'Il profilo deve avere almeno due tratti e una piega ogni due tratti.',
      ));
      return avvertimenti;
    }

    if (spessore <= 0) {
      avvertimenti.add(const Avvertimento.errore(
        CodiceAvvertimento.ingressoNonValido,
        'Lo spessore deve essere maggiore di zero.',
      ));
    }

    for (var i = 0; i < tratti.length; i++) {
      if (tratti[i].lunghezza <= 0) {
        avvertimenti.add(Avvertimento.errore(
          CodiceAvvertimento.ingressoNonValido,
          'Il tratto ${tratti[i].etichetta} deve essere maggiore di zero.',
        ));
      }
    }

    for (var i = 0; i < pieghe.length; i++) {
      final idMatrice = idMatricePer(i);
      final matrice = inventario.matricePerId(idMatrice);
      if (matrice == null) {
        final consigliata = RegolaMatrice.vConsigliata(spessore);
        avvertimenti.add(Avvertimento.errore(
          CodiceAvvertimento.nessunaCavaAdatta,
          'Piega ${i + 1}: nessuna cava selezionata. '
          'Per ${FormatoNumero.mm(spessore)} è consigliata la '
          'V${FormatoNumero.misura(consigliata, decimali: 0)}.',
          indicePiega: i,
        ));
      } else {
        avvertimenti.addAll(RegolaMatrice.verifica(matrice, spessore));
      }
    }

    return avvertimenti;
  }

  Map<String, dynamic> aMappa() => {
        'nome': nome,
        'spessore': spessore,
        'materiale': materiale.aMappa(),
        'quotatura': quotatura.name,
        if (idMatricePredefinita != null)
          'idMatricePredefinita': idMatricePredefinita,
        if (idPunzonePredefinito != null)
          'idPunzonePredefinito': idPunzonePredefinito,
        'tratti': [for (final t in tratti) t.aMappa()],
        'pieghe': [for (final p in pieghe) p.aMappa()],
      };

  static ProfiloLamiera daMappa(Map<String, dynamic> m) => ProfiloLamiera(
        nome: (m['nome'] as String?) ?? 'Pezzo',
        spessore: (m['spessore'] as num).toDouble(),
        materiale: m['materiale'] is Map
            ? Materiale.daMappa((m['materiale'] as Map).cast<String, dynamic>())
            : TabellaMateriali.acciaioDolce,
        quotatura: QuotaturaProfilo.values.firstWhere(
          (q) => q.name == m['quotatura'],
          orElse: () => QuotaturaProfilo.esterna,
        ),
        idMatricePredefinita: m['idMatricePredefinita'] as String?,
        idPunzonePredefinito: m['idPunzonePredefinito'] as String?,
        tratti: [
          for (final t in (m['tratti'] as List))
            TrattoProfilo.daMappa((t as Map).cast<String, dynamic>()),
        ],
        pieghe: [
          for (final p in (m['pieghe'] as List))
            PiegaProfilo.daMappa((p as Map).cast<String, dynamic>()),
        ],
      );

  static String _etichettaPer(int indice) {
    const lettere = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (indice < lettere.length) return lettere[indice];
    return 'L${indice + 1}';
  }

  @override
  String toString() =>
      'ProfiloLamiera($nome, S=$spessore, ${tratti.length} tratti)';
}
