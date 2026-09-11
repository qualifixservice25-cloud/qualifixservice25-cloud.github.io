import '../sequenza/collisioni.dart';
import '../sequenza/lato_minimo.dart';

/// Le preferenze dell'officina: i numeri che ogni reparto tara a modo suo.
class Impostazioni {
  final ParametriLatoMinimo latoMinimo;

  /// Gioco sotto il quale si parla di collisione, mm.
  final double giocoMinimo;

  /// Gioco che si vorrebbe avere, mm.
  final double giocoDesiderato;

  /// Decimali con cui mostrare le lunghezze.
  final int decimaliLunghezza;

  /// Decimali con cui mostrare i fattori adimensionali.
  final int decimaliFattore;

  /// Tema ad alto contrasto per lavorare accanto alla macchina.
  final bool modalitaOfficina;

  const Impostazioni({
    this.latoMinimo = const ParametriLatoMinimo(),
    this.giocoMinimo = RilevatoreCollisioni.giocoMinimoPredefinito,
    this.giocoDesiderato = 2.0,
    this.decimaliLunghezza = 1,
    this.decimaliFattore = 3,
    this.modalitaOfficina = false,
  });

  Impostazioni copiaCon({
    ParametriLatoMinimo? latoMinimo,
    double? giocoMinimo,
    double? giocoDesiderato,
    int? decimaliLunghezza,
    int? decimaliFattore,
    bool? modalitaOfficina,
  }) {
    return Impostazioni(
      latoMinimo: latoMinimo ?? this.latoMinimo,
      giocoMinimo: giocoMinimo ?? this.giocoMinimo,
      giocoDesiderato: giocoDesiderato ?? this.giocoDesiderato,
      decimaliLunghezza: decimaliLunghezza ?? this.decimaliLunghezza,
      decimaliFattore: decimaliFattore ?? this.decimaliFattore,
      modalitaOfficina: modalitaOfficina ?? this.modalitaOfficina,
    );
  }

  Map<String, dynamic> aMappa() => {
        'latoMinimo': latoMinimo.aMappa(),
        'giocoMinimo': giocoMinimo,
        'giocoDesiderato': giocoDesiderato,
        'decimaliLunghezza': decimaliLunghezza,
        'decimaliFattore': decimaliFattore,
        'modalitaOfficina': modalitaOfficina,
      };

  static Impostazioni daMappa(Map<String, dynamic> m) => Impostazioni(
        latoMinimo: m['latoMinimo'] is Map
            ? ParametriLatoMinimo.daMappa(
                (m['latoMinimo'] as Map).cast<String, dynamic>())
            : const ParametriLatoMinimo(),
        giocoMinimo: (m['giocoMinimo'] as num?)?.toDouble() ??
            RilevatoreCollisioni.giocoMinimoPredefinito,
        giocoDesiderato: (m['giocoDesiderato'] as num?)?.toDouble() ?? 2.0,
        decimaliLunghezza: (m['decimaliLunghezza'] as num?)?.toInt() ?? 1,
        decimaliFattore: (m['decimaliFattore'] as num?)?.toInt() ?? 3,
        modalitaOfficina: (m['modalitaOfficina'] as bool?) ?? false,
      );
}
