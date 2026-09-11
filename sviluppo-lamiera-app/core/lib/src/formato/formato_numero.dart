/// Formattazione numerica all'italiana: virgola decimale e punto per le
/// migliaia.
///
/// Scritta a mano invece di usare `intl` perché l'app è monolingua e `intl`
/// porterebbe con sé i dati di tutte le locale e la generazione l10n per
/// quindici righe di codice.
abstract final class FormatoNumero {
  /// Numero con [decimali] cifre e la virgola come separatore.
  ///
  /// Restituisce `'—'` per i valori non finiti: un NaN non deve mai arrivare
  /// a schermo travestito da misura.
  static String misura(double valore, {int decimali = 1, String unita = ''}) {
    if (!valore.isFinite) return '—';
    final testo = _conVirgola(valore.toStringAsFixed(decimali));
    return unita.isEmpty ? testo : '$testo $unita';
  }

  /// Lunghezza in millimetri.
  static String mm(double valore, {int decimali = 1}) =>
      misura(valore, decimali: decimali, unita: 'mm');

  /// Angolo in gradi.
  static String gradi(double valore, {int decimali = 1}) {
    if (!valore.isFinite) return '—';
    return '${_conVirgola(valore.toStringAsFixed(decimali))}°';
  }

  /// Fattore adimensionale (K, k, rapporti): tre decimali di default.
  static String fattore(double valore, {int decimali = 3}) =>
      misura(valore, decimali: decimali);

  static String _conVirgola(String testo) {
    final parti = testo.split('.');
    final intera = _conSeparatoreMigliaia(parti[0]);
    return parti.length == 1 ? intera : '$intera,${parti[1]}';
  }

  static String _conSeparatoreMigliaia(String intera) {
    final negativo = intera.startsWith('-');
    final cifre = negativo ? intera.substring(1) : intera;
    if (cifre.length <= 4) return intera;

    final buffer = StringBuffer();
    for (var i = 0; i < cifre.length; i++) {
      if (i > 0 && (cifre.length - i) % 3 == 0) buffer.write('.');
      buffer.write(cifre[i]);
    }
    return negativo ? '-$buffer' : buffer.toString();
  }

  /// Legge un numero scritto all'italiana (virgola) o all'inglese (punto).
  /// Restituisce null se non è interpretabile.
  static double? leggi(String testo) {
    final pulito = testo.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (pulito.isEmpty) return null;
    final valore = double.tryParse(pulito);
    return (valore != null && valore.isFinite) ? valore : null;
  }
}
