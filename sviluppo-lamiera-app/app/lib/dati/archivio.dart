import 'package:shared_preferences/shared_preferences.dart';

/// Deposito chiave-valore.
///
/// Interfaccia astratta così i test girano in memoria, senza plugin e senza
/// piattaforma sotto.
abstract class Archivio {
  Future<String?> leggi(String chiave);
  Future<void> scrivi(String chiave, String valore);
  Future<void> cancella(String chiave);
}

/// Implementazione reale.
///
/// `shared_preferences` è l'unico plugin dell'app: stessa API su Android
/// (SharedPreferences) e su web (localStorage), nessun codice condizionale,
/// nessun asset wasm da servire.
class ArchivioPreferenze implements Archivio {
  SharedPreferences? _preferenze;

  Future<SharedPreferences> get _istanza async =>
      _preferenze ??= await SharedPreferences.getInstance();

  @override
  Future<String?> leggi(String chiave) async {
    try {
      return (await _istanza).getString(chiave);
    } on Exception {
      // Dati del sito cancellati, modalità privata, quota esaurita: si riparte
      // dal catalogo invece di bloccare l'app.
      return null;
    }
  }

  @override
  Future<void> scrivi(String chiave, String valore) async {
    try {
      await (await _istanza).setString(chiave, valore);
    } on Exception {
      // Scrittura non riuscita: l'app resta usabile, si perde solo il
      // salvataggio. L'avviso all'utente sta nella schermata Impostazioni.
    }
  }

  @override
  Future<void> cancella(String chiave) async {
    try {
      await (await _istanza).remove(chiave);
    } on Exception {
      // Come sopra.
    }
  }
}

/// Archivio in memoria, per i test e per l'anteprima.
class ArchivioMemoria implements Archivio {
  final Map<String, String> _dati = {};

  @override
  Future<String?> leggi(String chiave) async => _dati[chiave];

  @override
  Future<void> scrivi(String chiave, String valore) async {
    _dati[chiave] = valore;
  }

  @override
  Future<void> cancella(String chiave) async {
    _dati.remove(chiave);
  }
}
