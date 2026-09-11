import 'materiale.dart';

/// Tabella dei materiali di partenza.
///
/// I coefficienti sono valori tipici da letteratura e da pratica di officina:
/// vanno confermati su un pezzo di prova con la taratura, perché ogni
/// combinazione di macchina, utensile e fornitore si comporta a modo suo.
abstract final class TabellaMateriali {
  static const acciaioDolce = Materiale(
    id: 'acciaio_dolce',
    nome: 'Acciaio dolce DC01',
    famiglia: 'Acciaio',
    coefficienteRaggio: 0.158,
    resistenzaTrazioneMPa: 400,
    rapportoRaggioSpessoreMinimo: 0.8,
  );

  static const acciaioS235 = Materiale(
    id: 'acciaio_s235',
    nome: 'Acciaio S235JR',
    famiglia: 'Acciaio',
    coefficienteRaggio: 0.158,
    resistenzaTrazioneMPa: 400,
    rapportoRaggioSpessoreMinimo: 1.0,
  );

  static const acciaioS355 = Materiale(
    id: 'acciaio_s355',
    nome: 'Acciaio S355JR',
    famiglia: 'Acciaio',
    coefficienteRaggio: 0.162,
    resistenzaTrazioneMPa: 550,
    rapportoRaggioSpessoreMinimo: 1.5,
  );

  static const acciaioZincato = Materiale(
    id: 'acciaio_zincato',
    nome: 'Acciaio zincato DX51D',
    famiglia: 'Acciaio',
    coefficienteRaggio: 0.158,
    resistenzaTrazioneMPa: 350,
    rapportoRaggioSpessoreMinimo: 1.0,
  );

  static const inox304 = Materiale(
    id: 'inox_304',
    nome: 'Inox AISI 304',
    famiglia: 'Inox',
    coefficienteRaggio: 0.175,
    resistenzaTrazioneMPa: 600,
    rapportoRaggioSpessoreMinimo: 1.2,
  );

  static const inox430 = Materiale(
    id: 'inox_430',
    nome: 'Inox AISI 430',
    famiglia: 'Inox',
    coefficienteRaggio: 0.170,
    resistenzaTrazioneMPa: 500,
    rapportoRaggioSpessoreMinimo: 1.0,
  );

  static const alluminio5754 = Materiale(
    id: 'alluminio_5754',
    nome: 'Alluminio 5754 H111',
    famiglia: 'Alluminio',
    coefficienteRaggio: 0.145,
    resistenzaTrazioneMPa: 220,
    rapportoRaggioSpessoreMinimo: 1.0,
  );

  static const alluminio6082 = Materiale(
    id: 'alluminio_6082',
    nome: 'Alluminio 6082 T6',
    famiglia: 'Alluminio',
    coefficienteRaggio: 0.150,
    resistenzaTrazioneMPa: 310,
    rapportoRaggioSpessoreMinimo: 2.5,
  );

  static const rame = Materiale(
    id: 'rame',
    nome: 'Rame Cu-DHP',
    famiglia: 'Rame e leghe',
    coefficienteRaggio: 0.140,
    resistenzaTrazioneMPa: 250,
    rapportoRaggioSpessoreMinimo: 0.5,
  );

  static const ottone = Materiale(
    id: 'ottone',
    nome: 'Ottone CuZn37',
    famiglia: 'Rame e leghe',
    coefficienteRaggio: 0.145,
    resistenzaTrazioneMPa: 340,
    rapportoRaggioSpessoreMinimo: 0.8,
  );

  static const List<Materiale> standard = [
    acciaioDolce,
    acciaioS235,
    acciaioS355,
    acciaioZincato,
    inox304,
    inox430,
    alluminio5754,
    alluminio6082,
    rame,
    ottone,
  ];

  /// Il materiale usato quando non ne è stato scelto nessuno.
  static const Materiale predefinito = acciaioDolce;

  static Materiale? perId(String id) {
    for (final m in standard) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Le famiglie nell'ordine in cui compaiono in tabella, senza ripetizioni.
  static List<String> get famiglie {
    final viste = <String>[];
    for (final m in standard) {
      if (!viste.contains(m.famiglia)) viste.add(m.famiglia);
    }
    return viste;
  }
}
