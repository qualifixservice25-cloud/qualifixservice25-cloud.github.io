import 'package:flutter/widgets.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import '../dati/archivio.dart';

/// Lo stato dell'app: un inventario, una tabella materiali, le impostazioni e
/// il pezzo su cui si sta lavorando.
///
/// `ChangeNotifier` e basta: nessuna libreria di state management. Cinque
/// schermate che leggono lo stesso documento non giustificano una dipendenza
/// in più né il modello mentale che si porta dietro.
class StatoApp extends ChangeNotifier {
  StatoApp(this._archivio);

  final Archivio _archivio;

  Inventario _inventario = Inventario.vuoto;
  List<Materiale> _materiali = TabellaMateriali.standard;
  Impostazioni _impostazioni = const Impostazioni();
  ProfiloLamiera _profilo = ProfiloLamiera.esempio();
  bool _caricato = false;
  bool _salvataggioRiuscito = true;

  Inventario get inventario => _inventario;
  List<Materiale> get materiali => _materiali;
  Impostazioni get impostazioni => _impostazioni;
  ProfiloLamiera get profilo => _profilo;
  bool get caricato => _caricato;
  bool get salvataggioRiuscito => _salvataggioRiuscito;

  // --- avvio ---------------------------------------------------------------

  Future<void> carica() async {
    final inventarioSalvato =
        ArchivioJson.inventarioDaTesto(await _archivio.leggi(ArchivioJson.chiaveInventario));
    _inventario = inventarioSalvato ?? CatalogoStandard.inventario();

    _materiali =
        ArchivioJson.materialiDaTesto(await _archivio.leggi(ArchivioJson.chiaveMateriali)) ??
            TabellaMateriali.standard;

    _impostazioni = ArchivioJson.impostazioniDaTesto(
            await _archivio.leggi(ArchivioJson.chiaveImpostazioni)) ??
        const Impostazioni();

    // Un pezzo di partenza già pronto da calcolare: la cava consigliata per lo
    // spessore predefinito, scelta fra quelle che si possiedono davvero.
    final cava = RegolaMatrice.miglioreDisponibile(_inventario, 2);
    final coltello = _inventario.punzoniOrdinati
        .where((p) => !p.eColloDoca)
        .firstOrNull;
    _profilo = _profilo.copiaCon(
      materiale: _materiali.isNotEmpty ? _materiali.first : null,
      idMatricePredefinita: cava?.id,
      idPunzonePredefinito: coltello?.id,
    );

    _caricato = true;
    notifyListeners();
  }

  // --- profilo -------------------------------------------------------------

  void aggiornaProfilo(ProfiloLamiera nuovo) {
    _profilo = nuovo;
    notifyListeners();
  }

  /// Cambia lo spessore e, se la cava scelta non è più adatta, propone quella
  /// giusta invece di lasciare in piedi una combinazione sbagliata.
  void impostaSpessore(double spessore) {
    var nuovo = _profilo.copiaCon(spessore: spessore);
    final attuale = _inventario.matricePerId(nuovo.idMatricePredefinita);
    final adatte = RegolaMatrice.compatibili(_inventario, spessore);
    if (attuale == null || !adatte.contains(attuale)) {
      final consigliata = RegolaMatrice.miglioreDisponibile(_inventario, spessore);
      nuovo = nuovo.copiaCon(idMatricePredefinita: consigliata?.id);
    }
    _profilo = nuovo;
    notifyListeners();
  }

  // --- risultati -----------------------------------------------------------

  RisultatoSviluppo get sviluppo =>
      CalcoloSviluppo.calcola(_profilo, _inventario);

  RisultatoSequenza get sequenza => MotoreSequenza.calcola(
        _profilo,
        _inventario,
        parametri: ParametriSequenza(
          giocoMinimo: _impostazioni.giocoMinimo,
          giocoDesiderato: _impostazioni.giocoDesiderato,
          latoMinimo: _impostazioni.latoMinimo,
        ),
      );

  // --- inventario ----------------------------------------------------------

  Future<void> salvaPunzone(Punzone punzone) async {
    _inventario = _inventario.conPunzone(punzone);
    notifyListeners();
    await _scriviInventario();
  }

  Future<void> eliminaPunzone(String id) async {
    _inventario = _inventario.senzaPunzone(id);
    notifyListeners();
    await _scriviInventario();
  }

  Future<void> salvaMatrice(Matrice matrice) async {
    _inventario = _inventario.conMatrice(matrice);
    notifyListeners();
    await _scriviInventario();
  }

  Future<void> eliminaMatrice(String id) async {
    _inventario = _inventario.senzaMatrice(id);
    if (_profilo.idMatricePredefinita == id) {
      _profilo = _profilo.copiaCon(
        idMatricePredefinita:
            RegolaMatrice.miglioreDisponibile(_inventario, _profilo.spessore)?.id,
      );
    }
    notifyListeners();
    await _scriviInventario();
  }

  Future<void> ripristinaCatalogo() async {
    _inventario = ArchivioJson.conCatalogoRipristinato(_inventario);
    _materiali = ArchivioJson.conMaterialiRipristinati(_materiali);
    notifyListeners();
    await _scriviInventario();
    await _scriviMateriali();
  }

  // --- materiali e taratura ------------------------------------------------

  Future<void> salvaMateriale(Materiale materiale) async {
    final nuovi = [..._materiali];
    final i = nuovi.indexWhere((m) => m.id == materiale.id);
    if (i >= 0) {
      nuovi[i] = materiale;
    } else {
      nuovi.add(materiale);
    }
    _materiali = nuovi;
    if (_profilo.materiale.id == materiale.id) {
      _profilo = _profilo.copiaCon(materiale: materiale);
    }
    notifyListeners();
    await _scriviMateriali();
  }

  /// Applica al materiale corrente la correzione ricavata da un provino.
  Future<bool> taraSuSviluppoMisurato(double sviluppoMisurato) async {
    final correzione = CalibrazioneK.correzioneDaSviluppoMisurato(
      profilo: _profilo,
      inventario: _inventario,
      sviluppoMisurato: sviluppoMisurato,
    );
    if (correzione == null) return false;
    await salvaMateriale(
      CalibrazioneK.materialeTarato(_profilo.materiale, correzione),
    );
    return true;
  }

  Future<void> azzeraTaratura() async {
    await salvaMateriale(_profilo.materiale.copiaCon(correzioneK: 1.0));
  }

  // --- impostazioni --------------------------------------------------------

  Future<void> aggiornaImpostazioni(Impostazioni nuove) async {
    _impostazioni = nuove;
    notifyListeners();
    await _archivio.scrivi(
      ArchivioJson.chiaveImpostazioni,
      ArchivioJson.impostazioniATesto(nuove),
    );
  }

  // --- scritture -----------------------------------------------------------

  Future<void> _scriviInventario() async {
    await _archivio.scrivi(
      ArchivioJson.chiaveInventario,
      ArchivioJson.inventarioATesto(_inventario),
    );
    _salvataggioRiuscito = await _archivio.leggi(ArchivioJson.chiaveInventario) != null;
  }

  Future<void> _scriviMateriali() async {
    await _archivio.scrivi(
      ArchivioJson.chiaveMateriali,
      ArchivioJson.materialiATesto(_materiali),
    );
  }
}

/// Rende lo stato disponibile a tutto l'albero senza pacchetti esterni.
class FornitoreStato extends InheritedNotifier<StatoApp> {
  const FornitoreStato({
    super.key,
    required StatoApp stato,
    required super.child,
  }) : super(notifier: stato);

  static StatoApp di(BuildContext context) {
    final fornitore =
        context.dependOnInheritedWidgetOfExactType<FornitoreStato>();
    assert(fornitore != null, 'FornitoreStato non trovato nell\'albero');
    return fornitore!.notifier!;
  }
}
