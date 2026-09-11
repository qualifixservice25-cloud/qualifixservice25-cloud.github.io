import '../diagnostica/avvertimento.dart';
import '../formato/formato_numero.dart';
import 'utensili.dart';

/// Regole di scelta della cava in funzione dello spessore.
///
/// Sono regole di officina, non leggi fisiche: servono a proporre, mai a
/// decidere di nascosto. Se in inventario non c'è una cava adatta, il calcolo
/// si ferma e lo dice — non ripiega in silenzio su un valore teorico.
abstract final class RegolaMatrice {
  /// Rapporto V/S consigliato per lo spessore dato.
  static double rapportoConsigliato(double spessore) {
    if (spessore <= 3) return 8;
    if (spessore <= 8) return 10;
    if (spessore <= 10) return 12;
    return 14;
  }

  /// Apertura consigliata: `V = rapporto · S`.
  static double vConsigliata(double spessore) =>
      rapportoConsigliato(spessore) * spessore;

  /// Rapporto V/S minimo accettabile prima che il tonnellaggio esploda e il
  /// materiale rischi la cricca.
  static const double rapportoMinimo = 6;

  /// Rapporto V/S massimo oltre il quale il raggio diventa troppo largo e la
  /// piega imprecisa.
  static const double rapportoMassimo = 16;

  /// Le cave dell'inventario utilizzabili per questo spessore, dalla più
  /// vicina alla consigliata in poi.
  static List<Matrice> compatibili(Inventario inventario, double spessore) {
    if (spessore <= 0) return const [];
    final consigliata = vConsigliata(spessore);
    final adatte = inventario.matrici.where((m) {
      final rapporto = m.aperturaV / spessore;
      return rapporto >= rapportoMinimo && rapporto <= rapportoMassimo;
    }).toList();
    adatte.sort((a, b) => (a.aperturaV - consigliata)
        .abs()
        .compareTo((b.aperturaV - consigliata).abs()));
    return adatte;
  }

  /// La cava migliore fra quelle possedute, o null se non ce n'è nessuna.
  static Matrice? miglioreDisponibile(Inventario inventario, double spessore) {
    final adatte = compatibili(inventario, spessore);
    return adatte.isEmpty ? null : adatte.first;
  }

  /// Controlla una cava scelta a mano e segnala se è fuori regola.
  static List<Avvertimento> verifica(Matrice matrice, double spessore) {
    if (spessore <= 0) return const [];
    final avvertimenti = <Avvertimento>[];
    final rapporto = matrice.aperturaV / spessore;
    final consigliata = vConsigliata(spessore);

    if (rapporto < rapportoMinimo) {
      avvertimenti.add(Avvertimento.attenzione(
        CodiceAvvertimento.cavaTroppoStretta,
        '${matrice.nome} è ${FormatoNumero.fattore(rapporto, decimali: 1)}×S: '
        'sotto ${rapportoMinimo.round()}×S servono molte più tonnellate e il '
        'raggio esterno rischia di criccare. '
        'Consigliata V${FormatoNumero.misura(consigliata, decimali: 0)}.',
      ));
    } else if (rapporto > rapportoMassimo) {
      avvertimenti.add(Avvertimento.attenzione(
        CodiceAvvertimento.cavaNonConsigliata,
        '${matrice.nome} è ${FormatoNumero.fattore(rapporto, decimali: 1)}×S: '
        'sopra ${rapportoMassimo.round()}×S il raggio si allarga e l\'angolo '
        'diventa poco ripetibile. '
        'Consigliata V${FormatoNumero.misura(consigliata, decimali: 0)}.',
      ));
    }
    return avvertimenti;
  }
}
