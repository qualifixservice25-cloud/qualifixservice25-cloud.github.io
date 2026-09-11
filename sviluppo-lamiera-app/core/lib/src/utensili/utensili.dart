import '../geometria/poligono.dart';
import 'sagoma_utensile.dart';

/// Famiglia di un punzone. Cambia la sagoma generata e il modo in cui il
/// motore di sequenza lo propone.
enum TipoPunzone {
  /// Punzone dritto, il caso normale.
  standard,

  /// Collo d'oca: il fusto rientra per lasciar passare il lembo già piegato.
  /// È la risposta ai profili a Z e alle pieghe di ritorno.
  colloDoca,

  /// Lama sottile per pieghe strette e canali.
  aColtello;

  String get etichetta => switch (this) {
        TipoPunzone.standard => 'Standard',
        TipoPunzone.colloDoca => "Collo d'oca",
        TipoPunzone.aColtello => 'A coltello',
      };
}

/// Un coltello (punzone) del parco utensili.
class Punzone {
  final String id;
  final String nome;

  /// Angolo compreso fra i fianchi, in gradi.
  final double angoloPunta;

  /// Raggio dello spigolo che tocca la lamiera, mm.
  final double raggioPunta;

  /// Ingombro verticale utile, mm.
  final double altezza;

  /// Larghezza del fusto, mm.
  final double larghezzaCorpo;

  /// Carico massimo ammesso, kN per metro di utensile.
  final double caricoMaxKnPerMetro;

  final TipoPunzone tipo;

  /// Rientranza del fusto per il collo d'oca, mm. Zero per gli altri tipi.
  final double gollaProfondita;

  /// Altezza del tratto rientrato, mm.
  final double gollaAltezza;

  /// Da che lato sta la rientranza.
  final bool gollaADestra;

  /// Voce di catalogo: si può copiare e modificare, non eliminare.
  final bool diSistema;

  Punzone({
    required this.id,
    required this.nome,
    required this.angoloPunta,
    required this.raggioPunta,
    required this.altezza,
    this.larghezzaCorpo = 30,
    this.caricoMaxKnPerMetro = 1000,
    this.tipo = TipoPunzone.standard,
    this.gollaProfondita = 0,
    this.gollaAltezza = 0,
    this.gollaADestra = true,
    this.diSistema = false,
  });

  /// Sagoma con la punta nell'origine, calcolata una sola volta.
  late final Poligono sagoma = SagomaUtensile.punzone(
    angoloPunta: angoloPunta,
    raggioPunta: raggioPunta,
    altezza: altezza,
    larghezzaCorpo: larghezzaCorpo,
    gollaProfondita: tipo == TipoPunzone.colloDoca ? gollaProfondita : 0,
    gollaAltezza: tipo == TipoPunzone.colloDoca ? gollaAltezza : 0,
    gollaADestra: gollaADestra,
  );

  bool get eColloDoca => tipo == TipoPunzone.colloDoca;

  Punzone copiaCon({
    String? id,
    String? nome,
    double? angoloPunta,
    double? raggioPunta,
    double? altezza,
    double? larghezzaCorpo,
    double? caricoMaxKnPerMetro,
    TipoPunzone? tipo,
    double? gollaProfondita,
    double? gollaAltezza,
    bool? gollaADestra,
    bool? diSistema,
  }) {
    return Punzone(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      angoloPunta: angoloPunta ?? this.angoloPunta,
      raggioPunta: raggioPunta ?? this.raggioPunta,
      altezza: altezza ?? this.altezza,
      larghezzaCorpo: larghezzaCorpo ?? this.larghezzaCorpo,
      caricoMaxKnPerMetro: caricoMaxKnPerMetro ?? this.caricoMaxKnPerMetro,
      tipo: tipo ?? this.tipo,
      gollaProfondita: gollaProfondita ?? this.gollaProfondita,
      gollaAltezza: gollaAltezza ?? this.gollaAltezza,
      gollaADestra: gollaADestra ?? this.gollaADestra,
      diSistema: diSistema ?? this.diSistema,
    );
  }

  Map<String, dynamic> aMappa() => {
        'id': id,
        'nome': nome,
        'angoloPunta': angoloPunta,
        'raggioPunta': raggioPunta,
        'altezza': altezza,
        'larghezzaCorpo': larghezzaCorpo,
        'caricoMaxKnPerMetro': caricoMaxKnPerMetro,
        'tipo': tipo.name,
        'gollaProfondita': gollaProfondita,
        'gollaAltezza': gollaAltezza,
        'gollaADestra': gollaADestra,
        'diSistema': diSistema,
      };

  static Punzone daMappa(Map<String, dynamic> m) => Punzone(
        id: m['id'] as String,
        nome: m['nome'] as String,
        angoloPunta: (m['angoloPunta'] as num).toDouble(),
        raggioPunta: (m['raggioPunta'] as num).toDouble(),
        altezza: (m['altezza'] as num).toDouble(),
        larghezzaCorpo: (m['larghezzaCorpo'] as num?)?.toDouble() ?? 30,
        caricoMaxKnPerMetro:
            (m['caricoMaxKnPerMetro'] as num?)?.toDouble() ?? 1000,
        tipo: TipoPunzone.values.firstWhere(
          (t) => t.name == m['tipo'],
          orElse: () => TipoPunzone.standard,
        ),
        gollaProfondita: (m['gollaProfondita'] as num?)?.toDouble() ?? 0,
        gollaAltezza: (m['gollaAltezza'] as num?)?.toDouble() ?? 0,
        gollaADestra: (m['gollaADestra'] as bool?) ?? true,
        diSistema: (m['diSistema'] as bool?) ?? false,
      );

  @override
  String toString() => 'Punzone($nome)';
}

/// Una cava (matrice) del parco utensili.
class Matrice {
  final String id;
  final String nome;

  /// Apertura della V, mm. È il numero che decide il raggio di piega.
  final double aperturaV;

  /// Angolo della V, gradi (85, 88, 90…).
  final double angoloV;

  /// Raggio di raccordo delle spalle, mm.
  final double raggioSpalla;

  /// Ingombro verticale, mm.
  final double altezza;

  /// Larghezza del corpo, mm. Zero significa "deducila dall'apertura".
  final double larghezza;

  final double caricoMaxKnPerMetro;

  final bool diSistema;

  Matrice({
    required this.id,
    required this.nome,
    required this.aperturaV,
    this.angoloV = 85,
    this.raggioSpalla = 1.0,
    this.altezza = 60,
    this.larghezza = 0,
    this.caricoMaxKnPerMetro = 1000,
    this.diSistema = false,
  });

  /// Quanto scende l'apice della V sotto il piano delle spalle.
  late final double profondita =
      SagomaUtensile.profonditaCava(aperturaV, angoloV);

  late final Poligono sagoma = SagomaUtensile.matriceAV(
    aperturaV: aperturaV,
    angoloV: angoloV,
    raggioSpalla: raggioSpalla,
    altezza: altezza,
    larghezza: larghezza,
  );

  Matrice copiaCon({
    String? id,
    String? nome,
    double? aperturaV,
    double? angoloV,
    double? raggioSpalla,
    double? altezza,
    double? larghezza,
    double? caricoMaxKnPerMetro,
    bool? diSistema,
  }) {
    return Matrice(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      aperturaV: aperturaV ?? this.aperturaV,
      angoloV: angoloV ?? this.angoloV,
      raggioSpalla: raggioSpalla ?? this.raggioSpalla,
      altezza: altezza ?? this.altezza,
      larghezza: larghezza ?? this.larghezza,
      caricoMaxKnPerMetro: caricoMaxKnPerMetro ?? this.caricoMaxKnPerMetro,
      diSistema: diSistema ?? this.diSistema,
    );
  }

  Map<String, dynamic> aMappa() => {
        'id': id,
        'nome': nome,
        'aperturaV': aperturaV,
        'angoloV': angoloV,
        'raggioSpalla': raggioSpalla,
        'altezza': altezza,
        'larghezza': larghezza,
        'caricoMaxKnPerMetro': caricoMaxKnPerMetro,
        'diSistema': diSistema,
      };

  static Matrice daMappa(Map<String, dynamic> m) => Matrice(
        id: m['id'] as String,
        nome: m['nome'] as String,
        aperturaV: (m['aperturaV'] as num).toDouble(),
        angoloV: (m['angoloV'] as num?)?.toDouble() ?? 85,
        raggioSpalla: (m['raggioSpalla'] as num?)?.toDouble() ?? 1.0,
        altezza: (m['altezza'] as num?)?.toDouble() ?? 60,
        larghezza: (m['larghezza'] as num?)?.toDouble() ?? 0,
        caricoMaxKnPerMetro:
            (m['caricoMaxKnPerMetro'] as num?)?.toDouble() ?? 1000,
        diSistema: (m['diSistema'] as bool?) ?? false,
      );

  @override
  String toString() => 'Matrice($nome, V=$aperturaV)';
}

/// Il parco utensili personale: quello che c'è davvero in officina.
class Inventario {
  final List<Punzone> punzoni;
  final List<Matrice> matrici;

  const Inventario({this.punzoni = const [], this.matrici = const []});

  static const Inventario vuoto = Inventario();

  bool get eVuoto => punzoni.isEmpty && matrici.isEmpty;

  Punzone? punzonePerId(String? id) {
    if (id == null) return null;
    for (final p in punzoni) {
      if (p.id == id) return p;
    }
    return null;
  }

  Matrice? matricePerId(String? id) {
    if (id == null) return null;
    for (final m in matrici) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Matrici ordinate per apertura crescente.
  List<Matrice> get matriciOrdinate {
    final copia = [...matrici];
    copia.sort((a, b) => a.aperturaV.compareTo(b.aperturaV));
    return copia;
  }

  /// Punzoni ordinati per raggio di punta, poi per angolo.
  List<Punzone> get punzoniOrdinati {
    final copia = [...punzoni];
    copia.sort((a, b) {
      final perRaggio = a.raggioPunta.compareTo(b.raggioPunta);
      return perRaggio != 0 ? perRaggio : a.angoloPunta.compareTo(b.angoloPunta);
    });
    return copia;
  }

  /// Inserisce o sostituisce un punzone, in modo immutabile.
  Inventario conPunzone(Punzone p) {
    final nuovi = [...punzoni];
    final i = nuovi.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      nuovi[i] = p;
    } else {
      nuovi.add(p);
    }
    return Inventario(punzoni: nuovi, matrici: matrici);
  }

  Inventario senzaPunzone(String id) => Inventario(
        punzoni: punzoni.where((p) => p.id != id).toList(),
        matrici: matrici,
      );

  Inventario conMatrice(Matrice m) {
    final nuove = [...matrici];
    final i = nuove.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      nuove[i] = m;
    } else {
      nuove.add(m);
    }
    return Inventario(punzoni: punzoni, matrici: nuove);
  }

  Inventario senzaMatrice(String id) => Inventario(
        punzoni: punzoni,
        matrici: matrici.where((m) => m.id != id).toList(),
      );

  @override
  String toString() =>
      'Inventario(${punzoni.length} punzoni, ${matrici.length} matrici)';
}
