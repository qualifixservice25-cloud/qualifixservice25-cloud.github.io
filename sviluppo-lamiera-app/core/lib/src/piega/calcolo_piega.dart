import 'dart:math' as math;

import '../diagnostica/avvertimento.dart';
import '../formato/formato_numero.dart';
import '../geometria/vec2.dart';
import '../materiali/materiale.dart';
import 'fattore_k.dart';

/// Da dove viene un valore mostrato a schermo.
///
/// L'operatore deve sempre poter sapere chi ha deciso un numero: la formula,
/// lui stesso, o una taratura fatta su un pezzo vero.
enum OrigineValore {
  /// Ricavato dalla cava con `Ri = c · V`.
  calcolatoDaCava,

  /// Ricavato dalla formula DIN 6935.
  din6935,

  /// Imposto a mano dall'operatore.
  impostoDallUtente,

  /// Ricavato dalla taratura su un pezzo di prova.
  tarato;

  String get etichetta => switch (this) {
        OrigineValore.calcolatoDaCava => 'dalla cava',
        OrigineValore.din6935 => 'DIN 6935',
        OrigineValore.impostoDallUtente => 'impostato da te',
        OrigineValore.tarato => 'tarato su prova',
      };
}

/// Un anello della catena di calcolo, pronto da mostrare in una riga.
///
/// Non è decorazione: è il modo in cui un piegatore esperto controlla che il
/// numero finale non sia sbagliato. Un risultato nudo non è verificabile.
class PassoCatena {
  final String etichetta;
  final String formula;
  final String valore;
  final OrigineValore origine;

  const PassoCatena({
    required this.etichetta,
    required this.formula,
    required this.valore,
    required this.origine,
  });

  @override
  String toString() => '$etichetta: $formula = $valore';
}

/// Gli ingressi di una singola piega.
class ParametriPiega {
  /// Spessore della lamiera, mm.
  final double spessore;

  /// Angolo formato, quello che si legge sul pezzo con il goniometro.
  /// 90° = squadra, 180° = lamiera piatta.
  final double angoloFormato;

  /// Apertura della cava, mm.
  final double aperturaV;

  final Materiale materiale;

  /// Raggio interno misurato davvero, se l'operatore lo conosce.
  /// Quando è null viene ricavato dalla cava.
  final double? raggioInternoForzato;

  /// Fattore K imposto a mano, se l'operatore vuole scavalcare la formula.
  final double? fattoreKForzato;

  const ParametriPiega({
    required this.spessore,
    required this.angoloFormato,
    required this.aperturaV,
    required this.materiale,
    this.raggioInternoForzato,
    this.fattoreKForzato,
  });

  ParametriPiega copiaCon({
    double? spessore,
    double? angoloFormato,
    double? aperturaV,
    Materiale? materiale,
    double? raggioInternoForzato,
    double? fattoreKForzato,
  }) {
    return ParametriPiega(
      spessore: spessore ?? this.spessore,
      angoloFormato: angoloFormato ?? this.angoloFormato,
      aperturaV: aperturaV ?? this.aperturaV,
      materiale: materiale ?? this.materiale,
      raggioInternoForzato: raggioInternoForzato ?? this.raggioInternoForzato,
      fattoreKForzato: fattoreKForzato ?? this.fattoreKForzato,
    );
  }
}

/// L'esito completo del calcolo di una piega, catena di derivazione compresa.
class RisultatoPiega {
  final double spessore;

  /// α — angolo formato, letto sul pezzo.
  final double angoloFormato;

  /// β = 180 − α — angolo di rotazione, quello che spazza l'arco.
  final double angoloRotazione;

  final double aperturaV;
  final double raggioInterno;
  final double rapportoRaggioSpessore;

  /// Coefficiente `k` grezzo della DIN 6935, prima della divisione per due.
  final double kDin;

  /// Fattore K effettivamente usato.
  final double fattoreK;

  /// Sviluppo dell'arco ("abbuono").
  final double ba;

  /// Sporgenza esterna.
  final double ossb;

  /// Detrazione ("cala").
  final double bd;

  final OrigineValore origineRaggio;
  final OrigineValore origineK;

  final List<PassoCatena> catena;
  final List<Avvertimento> avvertimenti;

  const RisultatoPiega({
    required this.spessore,
    required this.angoloFormato,
    required this.angoloRotazione,
    required this.aperturaV,
    required this.raggioInterno,
    required this.rapportoRaggioSpessore,
    required this.kDin,
    required this.fattoreK,
    required this.ba,
    required this.ossb,
    required this.bd,
    required this.origineRaggio,
    required this.origineK,
    required this.catena,
    required this.avvertimenti,
  });

  /// Raggio esterno della piega.
  double get raggioEsterno => raggioInterno + spessore;

  /// La detrazione espressa in spessori: è il controllo di buon senso che ogni
  /// piegatore fa a mente. Per acciaio dolce a 90° con V = 8·S deve dare ≈ 2.
  double get bdInSpessori => spessore <= 0 ? 0 : bd / spessore;

  bool get eAttendibile => !avvertimenti.haErrori;

  @override
  String toString() => 'RisultatoPiega(α=$angoloFormato°, V=$aperturaV, '
      'Ri=${raggioInterno.toStringAsFixed(2)}, K=${fattoreK.toStringAsFixed(3)}, '
      'BD=${bd.toStringAsFixed(3)})';
}

/// Il motore di calcolo della singola piega.
abstract final class CalcoloPiega {
  /// Sotto questo angolo la piega in aria esce dal suo regime e i coefficienti
  /// tabellari non valgono più.
  static const double angoloMinimoAffidabile = 30.0;

  /// Rapporto V/S sotto il quale la cava è troppo stretta per lo spessore.
  static const double rapportoCavaMinimo = 6.0;

  /// Raggio interno prodotto dalla cava in piega in aria: `Ri = c · V`.
  static double raggioInternoDaCava(double aperturaV, Materiale materiale) =>
      aperturaV * materiale.coefficienteRaggio;

  /// Sviluppo dell'arco: `BA = (π/180) · β · (Ri + K·S)`.
  static double bendAllowance({
    required double angoloRotazione,
    required double raggioInterno,
    required double fattoreK,
    required double spessore,
  }) =>
      gradiInRadianti(angoloRotazione) * (raggioInterno + fattoreK * spessore);

  /// Sporgenza esterna: `OSSB = tan(β/2) · (Ri + S)`.
  static double outsideSetback({
    required double angoloRotazione,
    required double raggioInterno,
    required double spessore,
  }) =>
      math.tan(gradiInRadianti(angoloRotazione / 2)) *
      (raggioInterno + spessore);

  /// Detrazione: `BD = 2·OSSB − BA`.
  static double bendDeduction({required double ossb, required double ba}) =>
      2 * ossb - ba;

  /// Calcola la piega e costruisce la catena di derivazione visibile.
  static RisultatoPiega calcola(ParametriPiega p) {
    final avvertimenti = <Avvertimento>[];
    final catena = <PassoCatena>[];

    final spessore = p.spessore;
    final aperturaV = p.aperturaV;
    final materiale = p.materiale;

    if (spessore <= 0) {
      avvertimenti.add(const Avvertimento.errore(
        CodiceAvvertimento.ingressoNonValido,
        'Lo spessore deve essere maggiore di zero.',
      ));
    }
    if (aperturaV <= 0 && p.raggioInternoForzato == null) {
      avvertimenti.add(const Avvertimento.errore(
        CodiceAvvertimento.ingressoNonValido,
        'Serve una cava, oppure un raggio interno misurato.',
      ));
    }

    // α ammesso fra 1° e 180°. Sotto 1° non è più piega in aria ma
    // schiacciatura, e tan(β/2) esplode.
    final angoloFormato = p.angoloFormato.clamp(1.0, 180.0);
    if ((angoloFormato - p.angoloFormato).abs() > 1e-9) {
      avvertimenti.add(Avvertimento.errore(
        CodiceAvvertimento.ingressoNonValido,
        'Angolo ${FormatoNumero.gradi(p.angoloFormato)} fuori intervallo: '
        'ammessi da 1° a 180°.',
      ));
    }
    final angoloRotazione = 180.0 - angoloFormato;

    if (angoloFormato < angoloMinimoAffidabile && angoloFormato > 1.0) {
      avvertimenti.add(Avvertimento.attenzione(
        CodiceAvvertimento.angoloFuoriRegime,
        'Sotto i ${angoloMinimoAffidabile.round()}° la piega in aria esce dal '
        'suo regime: verifica su un ritaglio prima di lavorare la serie.',
      ));
    }

    // --- Anello 1: il raggio interno ---------------------------------------
    final double raggioInterno;
    final OrigineValore origineRaggio;
    if (p.raggioInternoForzato != null) {
      raggioInterno = p.raggioInternoForzato!;
      origineRaggio = OrigineValore.impostoDallUtente;
      catena.add(PassoCatena(
        etichetta: 'Raggio interno',
        formula: 'misurato sul pezzo',
        valore: FormatoNumero.mm(raggioInterno, decimali: 2),
        origine: origineRaggio,
      ));
    } else {
      raggioInterno = raggioInternoDaCava(aperturaV, materiale);
      origineRaggio = OrigineValore.calcolatoDaCava;
      catena.add(PassoCatena(
        etichetta: 'Raggio interno dalla cava',
        formula: 'Ri = c · V = '
            '${FormatoNumero.fattore(materiale.coefficienteRaggio)} · '
            '${FormatoNumero.misura(aperturaV)}',
        valore: FormatoNumero.mm(raggioInterno, decimali: 2),
        origine: origineRaggio,
      ));
    }

    // --- Anello 2: il rapporto Ri/S ----------------------------------------
    final rapporto = FattoreK.rapportoRaggioSpessore(raggioInterno, spessore);
    catena.add(PassoCatena(
      etichetta: 'Rapporto raggio/spessore',
      formula: 'Ri / S = ${FormatoNumero.misura(raggioInterno, decimali: 2)} / '
          '${FormatoNumero.misura(spessore, decimali: 2)}',
      valore: FormatoNumero.fattore(rapporto, decimali: 2),
      origine: origineRaggio,
    ));

    if (rapporto < materiale.rapportoRaggioSpessoreMinimo && spessore > 0) {
      avvertimenti.add(Avvertimento.attenzione(
        CodiceAvvertimento.raggioSuSpessoreBasso,
        'Ri/S = ${FormatoNumero.fattore(rapporto, decimali: 2)} è sotto il '
        'minimo di ${FormatoNumero.fattore(materiale.rapportoRaggioSpessoreMinimo, decimali: 2)} '
        'per ${materiale.nome}: rischio di cricca sul raggio esterno. '
        'Usa una cava più larga.',
      ));
    }

    // --- Anello 3: il fattore K --------------------------------------------
    final kDin = FattoreK.kDin6935(raggioInterno, spessore);
    final double fattoreK;
    final OrigineValore origineK;
    if (p.fattoreKForzato != null) {
      fattoreK = p.fattoreKForzato!.clamp(0.0, FattoreK.massimo);
      origineK = OrigineValore.impostoDallUtente;
      catena.add(PassoCatena(
        etichetta: 'Fattore K',
        formula: 'impostato a mano',
        valore: FormatoNumero.fattore(fattoreK),
        origine: origineK,
      ));
    } else {
      fattoreK = FattoreK.fattoreK(
        raggioInterno,
        spessore,
        correzione: materiale.correzioneK,
      );
      origineK = materiale.eTarato ? OrigineValore.tarato : OrigineValore.din6935;
      catena.add(PassoCatena(
        etichetta: 'Coefficiente k (DIN 6935)',
        // "log10" e non "log₁₀": i pedici Unicode non stanno in Roboto, e
        // farli comparire costringerebbe l'app a scaricare un font di ripiego
        // da Google al primo avvio — proprio quello che si vuole evitare.
        formula: 'k = 0,65 + 0,5 · log10(${FormatoNumero.fattore(rapporto, decimali: 2)})',
        valore: FormatoNumero.fattore(kDin),
        origine: OrigineValore.din6935,
      ));
      catena.add(PassoCatena(
        etichetta: 'Fattore K',
        formula: materiale.eTarato
            ? 'K = k / 2 · ${FormatoNumero.fattore(materiale.correzioneK)} (taratura)'
            : 'K = k / 2',
        valore: FormatoNumero.fattore(fattoreK),
        origine: origineK,
      ));
      if (materiale.eTarato) {
        avvertimenti.add(Avvertimento.informazione(
          CodiceAvvertimento.kTarato,
          'Fattore K corretto di ×${FormatoNumero.fattore(materiale.correzioneK)} '
          'dalla tua taratura su ${materiale.nome}.',
        ));
      }
    }

    // --- Anello 4: abbuono, sporgenza, detrazione --------------------------
    final ba = bendAllowance(
      angoloRotazione: angoloRotazione,
      raggioInterno: raggioInterno,
      fattoreK: fattoreK,
      spessore: spessore,
    );
    final ossb = outsideSetback(
      angoloRotazione: angoloRotazione,
      raggioInterno: raggioInterno,
      spessore: spessore,
    );
    final bd = bendDeduction(ossb: ossb, ba: ba);

    catena.add(PassoCatena(
      etichetta: 'Abbuono (BA)',
      formula: 'BA = π/180 · ${FormatoNumero.gradi(angoloRotazione, decimali: 0)} · '
          '(${FormatoNumero.misura(raggioInterno, decimali: 2)} + '
          '${FormatoNumero.fattore(fattoreK)} · ${FormatoNumero.misura(spessore, decimali: 2)})',
      valore: FormatoNumero.mm(ba, decimali: 2),
      origine: origineK,
    ));
    catena.add(PassoCatena(
      etichetta: 'Sporgenza esterna (OSSB)',
      formula: 'OSSB = tan(${FormatoNumero.gradi(angoloRotazione / 2, decimali: 0)}) · '
          '(${FormatoNumero.misura(raggioInterno, decimali: 2)} + '
          '${FormatoNumero.misura(spessore, decimali: 2)})',
      valore: FormatoNumero.mm(ossb, decimali: 2),
      origine: origineRaggio,
    ));
    catena.add(PassoCatena(
      etichetta: 'Detrazione (BD)',
      formula: 'BD = 2 · ${FormatoNumero.misura(ossb, decimali: 2)} − '
          '${FormatoNumero.misura(ba, decimali: 2)}',
      valore: FormatoNumero.mm(bd, decimali: 2),
      origine: origineK,
    ));

    // --- Controlli sulla cava ----------------------------------------------
    if (aperturaV > 0 && spessore > 0) {
      final rapportoCava = aperturaV / spessore;
      if (rapportoCava < rapportoCavaMinimo) {
        avvertimenti.add(Avvertimento.attenzione(
          CodiceAvvertimento.cavaTroppoStretta,
          'V = ${FormatoNumero.misura(aperturaV)} è solo '
          '${FormatoNumero.fattore(rapportoCava, decimali: 1)} volte lo spessore: '
          'sotto ${rapportoCavaMinimo.round()}×S il tonnellaggio sale molto e '
          'il materiale rischia di criccare.',
        ));
      }
    }

    if (!ba.isFinite || !ossb.isFinite || !bd.isFinite) {
      avvertimenti.add(const Avvertimento.errore(
        CodiceAvvertimento.ingressoNonValido,
        'Il calcolo non ha prodotto un risultato valido: controlla i dati.',
      ));
    }

    return RisultatoPiega(
      spessore: spessore,
      angoloFormato: angoloFormato,
      angoloRotazione: angoloRotazione,
      aperturaV: aperturaV,
      raggioInterno: raggioInterno,
      rapportoRaggioSpessore: rapporto,
      kDin: kDin,
      fattoreK: fattoreK,
      ba: ba,
      ossb: ossb,
      bd: bd,
      origineRaggio: origineRaggio,
      origineK: origineK,
      catena: catena,
      avvertimenti: avvertimenti,
    );
  }
}
