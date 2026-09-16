import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sviluppo_lamiera/dati/archivio.dart';
import 'package:sviluppo_lamiera/disegno/zone_tocco.dart';
import 'package:sviluppo_lamiera/main.dart';
import 'package:sviluppo_lamiera/schermate/schermata_sviluppo.dart';

/// Il disegno è l'editor: questi test toccano esattamente dove il painter ha
/// messo i comandi, invece di indovinare le coordinate.
void main() {
  Future<void> apriSviluppo(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AppSviluppoLamiera(archivio: ArchivioMemoria()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.straighten_outlined));
    await tester.pumpAndSettle();
  }

  List<ZonaTocco> zoneDi(WidgetTester tester) {
    final stato = tester.state(find.byType(SchermataSviluppo));
    // ignore: avoid_dynamic_calls
    return (stato as dynamic).zone as List<ZonaTocco>;
  }

  /// Tocca il centro di una zona, convertito in coordinate dello schermo.
  Future<void> tocca(WidgetTester tester, ZonaTocco zona) async {
    final tela = find.descendant(
      of: find.byType(GestureDetector),
      matching: find.byType(CustomPaint),
    );
    final origine = tester.getTopLeft(tela.first);
    await tester.tapAt(origine + zona.area.center);
    await tester.pumpAndSettle();
  }

  ZonaTocco prima(WidgetTester tester, TipoZona tipo) =>
      zoneDi(tester).firstWhere((z) => z.tipo == tipo);

  /// Cerca solo dentro il foglio aperto: fuori ci sono gli stessi numeri
  /// (il numero della piega, le quote in tabella) e la ricerca diventa ambigua.
  Finder nelFoglio(String testo) => find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(testo),
      );

  testWidgets('il disegno espone quote, pieghe e i due «+»', (tester) async {
    await apriSviluppo(tester);
    final zone = zoneDi(tester);

    expect(zone.where((z) => z.tipo == TipoZona.lato).length, 2);
    expect(zone.where((z) => z.tipo == TipoZona.piega).length, 1);
    expect(zone.where((z) => z.tipo == TipoZona.aggiungiInizio).length, 1);
    expect(zone.where((z) => z.tipo == TipoZona.aggiungiFine).length, 1);
  });

  testWidgets('toccare una quota apre il tastierino e cambia lo sviluppo',
      (tester) async {
    await apriSviluppo(tester);
    expect(find.text('196,0 mm'), findsOneWidget);

    await tocca(tester, prima(tester, TipoZona.lato));
    expect(find.textContaining('Tratto'), findsWidgets);
    expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byIcon(Icons.backspace_outlined),
        ),
        findsOneWidget);

    await tester.tap(nelFoglio('1'));
    await tester.tap(nelFoglio('5'));
    await tester.tap(nelFoglio('0'));
    await tester.pumpAndSettle();
    await tester.tap(nelFoglio('Conferma'));
    await tester.pumpAndSettle();

    // 150 + 100 − 3,98
    expect(find.text('246,0 mm'), findsOneWidget);
  });

  testWidgets('toccare il badge apre la scheda della piega', (tester) async {
    await apriSviluppo(tester);

    await tocca(tester, prima(tester, TipoZona.piega));
    expect(find.text('Piega 1'), findsOneWidget);
    expect(find.text('VERSO'), findsOneWidget);

    await tester.tap(nelFoglio('120°'));
    await tester.pumpAndSettle();
    await tester.tap(nelFoglio('Conferma'));
    await tester.pumpAndSettle();

    // Aprendo l'angolo la detrazione cala, quindi lo sviluppo cresce.
    expect(find.text('196,0 mm'), findsNothing);
    expect(find.textContaining('198,'), findsWidgets);
  });

  testWidgets('il «+» in testa aggiunge un lato', (tester) async {
    await apriSviluppo(tester);
    expect(zoneDi(tester).where((z) => z.tipo == TipoZona.lato).length, 2);

    await tocca(tester, prima(tester, TipoZona.aggiungiInizio));

    expect(zoneDi(tester).where((z) => z.tipo == TipoZona.lato).length, 3);
    expect(zoneDi(tester).where((z) => z.tipo == TipoZona.piega).length, 2);
    // 50 + 100 + 100 − 2 × 3,98
    expect(find.text('242,0 mm'), findsOneWidget);
  });

  testWidgets('togliendo una piega i due lembi si sommano', (tester) async {
    await apriSviluppo(tester);
    await tocca(tester, prima(tester, TipoZona.aggiungiFine));
    expect(zoneDi(tester).where((z) => z.tipo == TipoZona.piega).length, 2);

    await tocca(tester, prima(tester, TipoZona.piega));
    expect(find.text('Piega 1'), findsOneWidget);
    await tester.tap(nelFoglio('Elimina'));
    await tester.pumpAndSettle();

    expect(zoneDi(tester).where((z) => z.tipo == TipoZona.piega).length, 1);
    expect(zoneDi(tester).where((z) => z.tipo == TipoZona.lato).length, 2);
  });
}
