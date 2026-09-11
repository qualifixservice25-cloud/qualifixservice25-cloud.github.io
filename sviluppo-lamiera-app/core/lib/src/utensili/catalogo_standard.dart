import '../formato/formato_numero.dart';
import 'utensili.dart';

/// Il parco utensili di partenza: una dotazione tipica di pressa piegatrice
/// europea.
///
/// Non è il tuo parco utensili, è un punto di partenza. Le voci sono marcate
/// `diSistema`, quindi si copiano e si modificano ma non si cancellano: chi
/// vuole il proprio utensile lo aggiunge, e chi vuole correggerne uno di
/// catalogo ne crea una copia con le misure giuste.
abstract final class CatalogoStandard {
  /// Aperture di cava della serie normale, in millimetri.
  static const List<double> apertureStandard = [
    4, 5, 6, 8, 10, 12, 16, 20, 25, 30, 35, 40, 50, 60, 80, 100,
  ];

  static List<Matrice> matrici() {
    return [
      for (final v in apertureStandard)
        Matrice(
          id: 'sys_matrice_v${_sigla(v)}',
          nome: 'Cava V${_sigla(v)} 85°',
          aperturaV: v,
          angoloV: 85,
          raggioSpalla: _raggioSpalla(v),
          altezza: v <= 16 ? 60 : 80,
          caricoMaxKnPerMetro: v <= 8 ? 600 : 1000,
          diSistema: true,
        ),
      // Una cava a 30° per le pieghe acute e le chiusure.
      Matrice(
        id: 'sys_matrice_v12_30',
        nome: 'Cava V12 30°',
        aperturaV: 12,
        angoloV: 30,
        raggioSpalla: 0.8,
        altezza: 60,
        caricoMaxKnPerMetro: 800,
        diSistema: true,
      ),
    ];
  }

  static List<Punzone> punzoni() {
    return [
      for (final r in const [0.2, 0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 3.0])
        Punzone(
          id: 'sys_punzone_88_r${_sigla(r)}',
          nome: 'Coltello 88° R${FormatoNumero.misura(r, decimali: 1)}',
          angoloPunta: 88,
          raggioPunta: r,
          altezza: 120,
          larghezzaCorpo: 26,
          caricoMaxKnPerMetro: 1000,
          diSistema: true,
        ),
      Punzone(
        id: 'sys_punzone_60_r06',
        nome: 'Coltello 60° R0,6',
        angoloPunta: 60,
        raggioPunta: 0.6,
        altezza: 120,
        larghezzaCorpo: 20,
        caricoMaxKnPerMetro: 800,
        diSistema: true,
      ),
      Punzone(
        id: 'sys_punzone_30_r08',
        nome: 'Coltello 30° R0,8 acuto',
        angoloPunta: 30,
        raggioPunta: 0.8,
        altezza: 120,
        larghezzaCorpo: 16,
        caricoMaxKnPerMetro: 600,
        tipo: TipoPunzone.aColtello,
        diSistema: true,
      ),
      Punzone(
        id: 'sys_punzone_colloDoca_r08',
        nome: "Collo d'oca 88° R0,8",
        angoloPunta: 88,
        raggioPunta: 0.8,
        altezza: 120,
        larghezzaCorpo: 40,
        caricoMaxKnPerMetro: 600,
        tipo: TipoPunzone.colloDoca,
        gollaProfondita: 16,
        gollaAltezza: 45,
        diSistema: true,
      ),
      Punzone(
        id: 'sys_punzone_colloDoca_r15',
        nome: "Collo d'oca 88° R1,5",
        angoloPunta: 88,
        raggioPunta: 1.5,
        altezza: 120,
        larghezzaCorpo: 40,
        caricoMaxKnPerMetro: 600,
        tipo: TipoPunzone.colloDoca,
        gollaProfondita: 20,
        gollaAltezza: 60,
        diSistema: true,
      ),
    ];
  }

  static Inventario inventario() =>
      Inventario(punzoni: punzoni(), matrici: matrici());

  /// Raccordo di spalla tipico: cresce con l'apertura.
  static double _raggioSpalla(double aperturaV) {
    if (aperturaV <= 6) return 0.4;
    if (aperturaV <= 12) return 0.8;
    if (aperturaV <= 25) return 1.5;
    if (aperturaV <= 50) return 3.0;
    return 5.0;
  }

  /// Sigla numerica per gli identificatori: `16` → `16`, `0.8` → `08`.
  static String _sigla(double valore) =>
      valore == valore.roundToDouble()
          ? valore.round().toString()
          : valore.toString().replaceAll('.', '');
}
