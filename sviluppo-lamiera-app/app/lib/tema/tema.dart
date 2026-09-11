import 'package:flutter/material.dart';

/// I colori del marchio Qualifix, gli stessi della landing page del sito.
abstract final class ColoriQualifix {
  static const Color primario = Color(0xFF2C3E50);
  static const Color primarioScuro = Color(0xFF1A252F);
  static const Color accento = Color(0xFFE67E22);
  static const Color successo = Color(0xFF27AE60);
  static const Color sfondo = Color(0xFFF8F9FA);
  static const Color errore = Color(0xFFC0392B);
  static const Color attenzione = Color(0xFFD68910);
}

/// Il tema dell'app.
///
/// Le scelte non sono estetiche: questa app si usa in piedi, accanto a una
/// pressa piegatrice, spesso con i guanti e con le mani sporche. Da qui
/// bersagli grandi, testo grosso e una modalità ad alto contrasto.
abstract final class TemaApp {
  /// Lato minimo di ogni elemento toccabile.
  static const double bersaglioMinimo = 56;

  /// Corpo del testo normale: più grande del default, si legge a distanza di
  /// braccio senza chinarsi sul tablet.
  static const double corpoTesto = 17;

  /// Corpo dei risultati principali.
  static const double corpoRisultato = 40;

  /// Quanto ingrandire il testo in modalità officina.
  ///
  /// Si applica via `MediaQuery`, non sul `TextTheme`: moltiplicare un tema i
  /// cui stili non hanno tutti un `fontSize` esplicito fa scattare un assert
  /// di Flutter.
  static const double ingrandimentoOfficina = 1.12;

  static ThemeData chiaro() => _costruisci(Brightness.light);

  static ThemeData officina() => _costruisci(Brightness.dark);

  static ThemeData _costruisci(Brightness luminosita) {
    final scuro = luminosita == Brightness.dark;

    final schema = ColorScheme.fromSeed(
      seedColor: ColoriQualifix.primario,
      brightness: luminosita,
    ).copyWith(
      primary: scuro ? const Color(0xFF7FB3D5) : ColoriQualifix.primario,
      secondary: ColoriQualifix.accento,
      error: scuro ? const Color(0xFFFF6B5A) : ColoriQualifix.errore,
      surface: scuro ? const Color(0xFF11161B) : Colors.white,
    );

    final base = ThemeData(
      colorScheme: schema,
      useMaterial3: true,
      brightness: luminosita,
      // Il Roboto impacchettato, non quello scaricato da Google al primo
      // avvio: l'app deve rendere lo stesso testo anche senza rete.
      fontFamily: 'Roboto',
      scaffoldBackgroundColor:
          scuro ? const Color(0xFF0A0D10) : ColoriQualifix.sfondo,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scuro ? const Color(0xFF11161B) : ColoriQualifix.primario,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: scuro ? 0 : 1,
        color: schema.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: scuro
              ? const BorderSide(color: Color(0xFF2A343D))
              : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scuro ? const Color(0xFF1A222A) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        labelStyle: const TextStyle(fontSize: corpoTesto),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, bersaglioMinimo),
          textStyle: const TextStyle(
            fontSize: corpoTesto,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, bersaglioMinimo),
          textStyle: const TextStyle(fontSize: corpoTesto),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: corpoTesto),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(64, bersaglioMinimo),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        titleTextStyle: TextStyle(fontSize: corpoTesto, fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scuro ? const Color(0xFF11161B) : Colors.white,
        indicatorColor: ColoriQualifix.accento.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scuro ? const Color(0xFF2A343D) : const Color(0xFFE8ECEF),
      ),
    );
  }
}
