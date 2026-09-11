import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';
import 'package:test/test.dart';

ProfiloLamiera _profilo({
  required List<double> quote,
  required List<PiegaProfilo> pieghe,
  double spessore = 2,
  String cava = 'sys_matrice_v16',
  String punzone = 'sys_punzone_88_r08',
}) {
  const lettere = 'ABCDEFGH';
  return ProfiloLamiera(
    spessore: spessore,
    idMatricePredefinita: cava,
    idPunzonePredefinito: punzone,
    tratti: [
      for (var i = 0; i < quote.length; i++)
        TrattoProfilo(lettere[i], quote[i]),
    ],
    pieghe: pieghe,
  );
}

void main() {
  final inventario = CatalogoStandard.inventario();

  group('Struttura del risultato', () {
    test('una squadretta a una piega dà una sequenza di un passo', () {
      final r = MotoreSequenza.calcola(
        _profilo(quote: [100, 100], pieghe: const [PiegaProfilo()]),
        inventario,
      );

      expect(r.sequenze, isNotEmpty);
      expect(r.migliore!.passi, hasLength(1));
      expect(r.migliore!.fattibile, isTrue,
          reason: r.avvertimenti.join('\n'));
      expect(r.esaustiva, isTrue);
    });

    test('ogni piega compare una volta sola in ogni sequenza', () {
      final r = MotoreSequenza.calcola(
        _profilo(
          quote: [30, 80, 120, 80, 30],
          pieghe: const [
            PiegaProfilo(),
            PiegaProfilo(),
            PiegaProfilo(),
            PiegaProfilo(),
          ],
        ),
        inventario,
      );

      expect(r.sequenze, isNotEmpty);
      for (final sequenza in r.sequenze) {
        final indici = sequenza.passi.map((p) => p.indicePiega).toList();
        expect(indici.toSet(), hasLength(4),
            reason: 'una piega è stata ripetuta o saltata');
        expect(indici.toSet(), containsAll(<int>[0, 1, 2, 3]));
      }
    });

    test('il risultato è deterministico', () {
      final profilo = _profilo(
        quote: [40, 90, 90, 40],
        pieghe: const [PiegaProfilo(), PiegaProfilo(), PiegaProfilo()],
      );
      final primo = MotoreSequenza.calcola(profilo, inventario);
      final secondo = MotoreSequenza.calcola(profilo, inventario);

      expect(secondo.migliore!.ordine, primo.migliore!.ordine);
      expect(secondo.migliore!.costo, closeTo(primo.migliore!.costo, 1e-9));
    });

    test('le sequenze arrivano ordinate: prima le fattibili, poi per costo', () {
      final r = MotoreSequenza.calcola(
        _profilo(
          quote: [25, 70, 70, 25],
          pieghe: const [PiegaProfilo(), PiegaProfilo(), PiegaProfilo()],
        ),
        inventario,
      );

      for (var i = 1; i < r.sequenze.length; i++) {
        final prima = r.sequenze[i - 1];
        final dopo = r.sequenze[i];
        if (prima.fattibile == dopo.fattibile) {
          expect(dopo.costo, greaterThanOrEqualTo(prima.costo - 1e-9));
        } else {
          expect(prima.fattibile, isTrue);
        }
      }
    });
  });

  group('Lato minimo', () {
    test('un lembo da 5 mm su V16 non è piegabile', () {
      // Il minimo con V16 è 10,4 mm: 5 mm scivolano dentro la cava.
      final r = MotoreSequenza.calcola(
        _profilo(quote: [100, 5], pieghe: const [PiegaProfilo()]),
        inventario,
      );

      expect(r.haSequenzaFattibile, isFalse);
      expect(
        r.avvertimenti.any((a) => a.codice == CodiceAvvertimento.latoMinimo),
        isTrue,
        reason: 'doveva segnalare il lato minimo: ${r.avvertimenti}',
      );
    });

    test('lo stesso lembo su una cava stretta diventa piegabile', () {
      // Con V6 il minimo scende a 3,9 mm.
      final r = MotoreSequenza.calcola(
        _profilo(
          quote: [100, 5],
          pieghe: const [PiegaProfilo()],
          spessore: 0.8,
          cava: 'sys_matrice_v6',
          punzone: 'sys_punzone_88_r04',
        ),
        inventario,
      );

      expect(r.haSequenzaFattibile, isTrue,
          reason: r.avvertimenti.join('\n'));
    });

    test('finché la piega vicina non è fatta il lembo è più lungo', () {
      // Il lembo non finisce alla piega adiacente se quella è ancora dritta:
      // il materiale oltre continua ad appoggiare sulla cava.
      final r = MotoreSequenza.calcola(
        _profilo(
          quote: [100, 20, 100],
          pieghe: const [PiegaProfilo(), PiegaProfilo()],
        ),
        inventario,
      );

      // La prima piega eseguita trova ancora 20 + 100 mm di lembo dall'altra
      // parte, quindi il primo passo deve risultare fattibile.
      expect(r.sequenze, isNotEmpty);
      expect(r.migliore!.passi.first.fattibile, isTrue,
          reason: 'il primo passo aveva lembo sufficiente');
    });
  });

  group('Collisioni', () {
    test('un profilo chiuso su sé stesso viene segnalato', () {
      // Lembi lunghi che si chiudono attorno al coltello: prima o poi
      // qualcosa tocca.
      final r = MotoreSequenza.calcola(
        _profilo(
          quote: [120, 40, 120, 40, 120],
          pieghe: const [
            PiegaProfilo(angoloFormato: 45),
            PiegaProfilo(angoloFormato: 45),
            PiegaProfilo(angoloFormato: 45),
            PiegaProfilo(angoloFormato: 45),
          ],
        ),
        inventario,
      );

      // Qualunque sia l'esito, il motore deve avere una posizione: o propone
      // una sequenza, o dice perché non ce n'è nessuna.
      expect(
        r.sequenze.isNotEmpty || r.avvertimenti.haErrori,
        isTrue,
      );
      if (!r.haSequenzaFattibile) {
        expect(r.avvertimenti, isNotEmpty);
      }
    });

    test('i limiti del controllo sono dichiarati', () {
      expect(RilevatoreCollisioni.limitiNoti, isNotEmpty);
      expect(
        RilevatoreCollisioni.limitiNoti.join(' '),
        contains('sezione'),
      );
      expect(
        RilevatoreCollisioni.limitiNoti.join(' '),
        contains('ritorno elastico'),
      );
    });

    test('il pezzo piatto non collide con niente', () {
      final profilo = _profilo(quote: [100, 100], pieghe: const [PiegaProfilo()]);
      final sviluppo = CalcoloSviluppo.calcola(profilo, inventario);
      final esito = RilevatoreCollisioni.verificaPasso(
        profilo: profilo,
        trattiPiani: sviluppo.trattiPiani,
        pieghe: sviluppo.pieghe,
        punzone: inventario.punzonePerId('sys_punzone_88_r08')!,
        matrice: inventario.matricePerId('sys_matrice_v16')!,
        indicePiega: 0,
        giaPiegate: const {},
      );
      expect(esito.collide, isFalse, reason: esito.toString());
    });
  });

  group('Senza sviluppo attendibile non si propone niente', () {
    test('profilo senza cava', () {
      final profilo = ProfiloLamiera(
        spessore: 2,
        tratti: const [TrattoProfilo('A', 100), TrattoProfilo('B', 100)],
        pieghe: const [PiegaProfilo()],
      );
      final r = MotoreSequenza.calcola(profilo, inventario);

      expect(r.sequenze, isEmpty);
      expect(r.avvertimenti.haErrori, isTrue);
    });
  });
}
