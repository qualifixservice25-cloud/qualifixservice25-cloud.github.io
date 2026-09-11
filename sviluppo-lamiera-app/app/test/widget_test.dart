import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sviluppo_lamiera/dati/archivio.dart';
import 'package:sviluppo_lamiera/main.dart';

/// Prove d'insieme sull'app vera, con un archivio in memoria al posto del
/// plugin: verificano che le schermate si costruiscano e che i numeri del
/// motore arrivino davvero a schermo.
void main() {
  Future<void> avvia(WidgetTester tester) async {
    // Finestra alta: le schermate sono liste lunghe e la superficie di prova
    // predefinita (800 × 600) taglierebbe fuori metà di quello che si vuole
    // verificare. Larghezza sotto i 900 per restare sul layout a colonna
    // singola, quello del tablet in verticale.
    tester.view.physicalSize = const Size(820, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AppSviluppoLamiera(archivio: ArchivioMemoria()));
    await tester.pumpAndSettle();
  }

  testWidgets('parte sulla scheda Piega con la catena di calcolo visibile',
      (tester) async {
    await avvia(tester);

    expect(find.text('Piega'), findsWidgets);
    expect(find.text('COME CI SI ARRIVA'), findsOneWidget);

    // La catena deve mostrare gli anelli, non solo il risultato.
    expect(find.text('Raggio interno dalla cava'), findsOneWidget);
    expect(find.text('Fattore K'), findsWidgets);
    expect(find.text('Detrazione (BD)'), findsOneWidget);

    // E i valori del caso di riferimento: V16 su 2 mm di acciaio dolce.
    expect(find.text('2,53 mm'), findsWidgets);
    expect(find.text('0,350'), findsWidgets);
  });

  testWidgets('la scheda Sviluppo mostra la lunghezza da tagliare',
      (tester) async {
    await avvia(tester);

    await tester.tap(find.byIcon(Icons.straighten_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Lunghezza da tagliare'.toUpperCase()), findsOneWidget);
    // Squadretta 100 × 100 con quote esterne su V16.
    expect(find.text('196,0 mm'), findsOneWidget);
  });

  testWidgets('la scheda Sequenza propone un ordine e dichiara i suoi limiti',
      (tester) async {
    await avvia(tester);

    await tester.tap(find.byIcon(Icons.reorder_outlined));
    await tester.pumpAndSettle();

    expect(find.text('ORDINE CONSIGLIATO'), findsOneWidget);
    expect(find.text('LIMITI DEL CONTROLLO'), findsOneWidget);
    expect(
      find.textContaining('proposte, non verifiche'),
      findsOneWidget,
    );
  });

  testWidgets("l'inventario parte dal catalogo standard", (tester) async {
    await avvia(tester);

    await tester.tap(find.byIcon(Icons.handyman_outlined));
    await tester.pumpAndSettle();

    expect(find.text('COLTELLI'), findsOneWidget);
    expect(find.text('CAVE'), findsOneWidget);
    expect(find.textContaining('Coltello 88°'), findsWidgets);
  });

  testWidgets('la modalità officina cambia tema', (tester) async {
    await avvia(tester);

    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Modalità officina'), findsOneWidget);

    final primaDi = Theme.of(tester.element(find.text('Modalità officina')));
    expect(primaDi.brightness, Brightness.light);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final dopo = Theme.of(tester.element(find.text('Modalità officina')));
    expect(dopo.brightness, Brightness.dark);
  });

  testWidgets('aggiungere un tratto allunga il pezzo', (tester) async {
    await avvia(tester);

    await tester.tap(find.byIcon(Icons.straighten_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Tratto C'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Aggiungi tratto'));
    await tester.pumpAndSettle();

    expect(find.text('Tratto C'), findsOneWidget);
    // Con un tratto in più lo sviluppo non è più quello della squadretta.
    expect(find.text('196,0 mm'), findsNothing);
  });
}
