import 'dart:convert';

import '../materiali/materiale.dart';
import '../materiali/tabella_materiali.dart';
import '../utensili/catalogo_standard.dart';
import '../utensili/utensili.dart';
import 'impostazioni.dart';

/// Serializzazione dell'inventario e delle impostazioni.
///
/// Sta nel core, non nel livello di persistenza, così è testabile senza
/// plugin e senza Flutter. Il numero di versione c'è dal primo giorno: costa
/// venti righe adesso e salva il parco utensili dell'utente fra un anno.
abstract final class ArchivioJson {
  static const int versioneSchema = 1;

  static const String chiaveInventario = 'inventario_v1';
  static const String chiaveImpostazioni = 'impostazioni_v1';
  static const String chiaveMateriali = 'materiali_v1';
  static const String chiaveProgetti = 'progetti_v1';

  // --- inventario ---------------------------------------------------------

  static Map<String, dynamic> inventarioAMappa(Inventario inventario) => {
        'versione': versioneSchema,
        'punzoni': [for (final p in inventario.punzoni) p.aMappa()],
        'matrici': [for (final m in inventario.matrici) m.aMappa()],
      };

  static Inventario inventarioDaMappa(Map<String, dynamic> mappa) {
    final migrata = _migra(mappa);
    return Inventario(
      punzoni: [
        for (final p in (migrata['punzoni'] as List? ?? const []))
          Punzone.daMappa((p as Map).cast<String, dynamic>()),
      ],
      matrici: [
        for (final m in (migrata['matrici'] as List? ?? const []))
          Matrice.daMappa((m as Map).cast<String, dynamic>()),
      ],
    );
  }

  static String inventarioATesto(Inventario inventario) =>
      jsonEncode(inventarioAMappa(inventario));

  /// Rilegge un inventario salvato. Restituisce null se il testo non è
  /// interpretabile, così chi chiama può ricadere sul catalogo di partenza
  /// invece di mostrare un'app vuota.
  static Inventario? inventarioDaTesto(String? testo) {
    if (testo == null || testo.trim().isEmpty) return null;
    try {
      final decodificato = jsonDecode(testo);
      if (decodificato is! Map) return null;
      return inventarioDaMappa(decodificato.cast<String, dynamic>());
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  // --- impostazioni -------------------------------------------------------

  static String impostazioniATesto(Impostazioni impostazioni) => jsonEncode({
        'versione': versioneSchema,
        ...impostazioni.aMappa(),
      });

  static Impostazioni? impostazioniDaTesto(String? testo) {
    if (testo == null || testo.trim().isEmpty) return null;
    try {
      final decodificato = jsonDecode(testo);
      if (decodificato is! Map) return null;
      return Impostazioni.daMappa(decodificato.cast<String, dynamic>());
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  // --- materiali ----------------------------------------------------------

  static String materialiATesto(List<Materiale> materiali) => jsonEncode({
        'versione': versioneSchema,
        'materiali': [for (final m in materiali) m.aMappa()],
      });

  static List<Materiale>? materialiDaTesto(String? testo) {
    if (testo == null || testo.trim().isEmpty) return null;
    try {
      final decodificato = jsonDecode(testo);
      if (decodificato is! Map) return null;
      final elenco = decodificato['materiali'];
      if (elenco is! List) return null;
      return [
        for (final m in elenco)
          Materiale.daMappa((m as Map).cast<String, dynamic>()),
      ];
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Rimette in tabella le voci di catalogo mancanti senza toccare quelle
  /// aggiunte o modificate dall'utente.
  static Inventario conCatalogoRipristinato(Inventario attuale) {
    var risultato = attuale;
    for (final p in CatalogoStandard.punzoni()) {
      if (attuale.punzonePerId(p.id) == null) risultato = risultato.conPunzone(p);
    }
    for (final m in CatalogoStandard.matrici()) {
      if (attuale.matricePerId(m.id) == null) risultato = risultato.conMatrice(m);
    }
    return risultato;
  }

  /// Stessa cosa per i materiali.
  static List<Materiale> conMaterialiRipristinati(List<Materiale> attuali) {
    final risultato = [...attuali];
    for (final standard in TabellaMateriali.standard) {
      if (!risultato.any((m) => m.id == standard.id)) risultato.add(standard);
    }
    return risultato;
  }

  /// Punto unico in cui gestire i cambi di schema futuri.
  static Map<String, dynamic> _migra(Map<String, dynamic> grezzo) {
    final versione = (grezzo['versione'] as num?)?.toInt() ?? 1;
    // Versione 1: nessuna migrazione necessaria. Le versioni successive si
    // innestano qui, una dopo l'altra.
    if (versione > versioneSchema) {
      // Un file scritto da una versione più nuova dell'app: si legge quello
      // che si riesce invece di buttare via tutto.
      return grezzo;
    }
    return grezzo;
  }
}
