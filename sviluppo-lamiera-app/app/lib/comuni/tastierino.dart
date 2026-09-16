import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import '../tema/tema.dart';

/// Tastierino numerico a tutta larghezza.
///
/// Scritto invece di usare la tastiera di sistema perché questa app si usa in
/// piedi, con i guanti e le mani unte: i tasti della tastiera di sistema sono
/// piccoli, metà non servono, e mangiano mezzo schermo.
///
/// Restituisce il valore confermato, oppure null se si annulla.
Future<double?> mostraTastierino(
  BuildContext context, {
  required String titolo,
  required double valore,
  String unita = 'mm',
  List<double> scatti = const [0.5, 1],
  double minimo = 0,
  double massimo = 99999,
  String? aiuto,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _Tastierino(
      titolo: titolo,
      valore: valore,
      unita: unita,
      scatti: scatti,
      minimo: minimo,
      massimo: massimo,
      aiuto: aiuto,
    ),
  );
}

class _Tastierino extends StatefulWidget {
  final String titolo;
  final double valore;
  final String unita;
  final List<double> scatti;
  final double minimo;
  final double massimo;
  final String? aiuto;

  const _Tastierino({
    required this.titolo,
    required this.valore,
    required this.unita,
    required this.scatti,
    required this.minimo,
    required this.massimo,
    this.aiuto,
  });

  @override
  State<_Tastierino> createState() => _TastierinoState();
}

class _TastierinoState extends State<_Tastierino> {
  late String _testo = _pulito(widget.valore);

  /// Alla prima cifra si riparte da zero, come su una bilancia: chi apre il
  /// tastierino di solito vuole scrivere un numero nuovo, non correggere
  /// l'ultima cifra di quello vecchio.
  bool _sostituisci = true;

  static String _pulito(double v) {
    final t = FormatoNumero.misura(v, decimali: 2);
    return t.contains(',')
        ? t.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r',$'), '')
        : t;
  }

  double? get _valore => FormatoNumero.leggi(_testo);

  bool get _valido {
    final v = _valore;
    return v != null && v >= widget.minimo && v <= widget.massimo;
  }

  void _cifra(String c) {
    setState(() {
      if (_sostituisci) {
        _testo = c == ',' ? '0,' : c;
        _sostituisci = false;
      } else {
        if (c == ',' && _testo.contains(',')) return;
        if (_testo.length >= 9) return;
        _testo += c;
      }
    });
  }

  void _cancella() {
    setState(() {
      _sostituisci = false;
      _testo = _testo.length <= 1 ? '0' : _testo.substring(0, _testo.length - 1);
    });
  }

  void _scatto(double quanto) {
    final attuale = _valore ?? 0;
    final nuovo = (attuale + quanto).clamp(widget.minimo, widget.massimo);
    setState(() {
      _testo = _pulito(nuovo.toDouble());
      _sostituisci = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.titolo,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (widget.aiuto != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.aiuto!,
                style: TextStyle(
                  fontSize: 13,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Il valore in costruzione, grande quanto serve per leggerlo da un
          // passo di distanza.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: tema.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: _valido
                  ? null
                  : Border.all(color: ColoriQualifix.errore, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _testo,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                if (widget.unita.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      widget.unita,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Scatti: aggiustare di mezzo millimetro è più veloce che riscrivere
          // tutto il numero, ed è quello che si fa nove volte su dieci.
          Row(
            children: [
              for (final s in [
                ...widget.scatti.reversed.map((v) => -v),
                ...widget.scatti,
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => _scatto(s),
                      child: Text(
                        '${s > 0 ? '+' : '−'}${FormatoNumero.misura(s.abs(), decimali: s.abs() % 1 == 0 ? 0 : 1)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          for (final riga in const [
            ['7', '8', '9'],
            ['4', '5', '6'],
            ['1', '2', '3'],
            [',', '0', _Tasto.cancella],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  for (final t in riga)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _Tasto(
                          testo: t,
                          onPremuto: () =>
                              t == _Tasto.cancella ? _cancella() : _cifra(t),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _valido
                      ? () => Navigator.of(context).pop(_valore)
                      : null,
                  child: const Text('Conferma'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tasto extends StatelessWidget {
  /// Segnaposto del tasto cancella.
  ///
  /// Non è il carattere ⌫: quel glifo non sta in Roboto e a schermo esce un
  /// rettangolo vuoto. Si disegna con un'icona Material, che è impacchettata
  /// con l'app e c'è di sicuro anche senza rete.
  static const String cancella = '\u0000canc';

  final String testo;
  final VoidCallback onPremuto;

  const _Tasto({required this.testo, required this.onPremuto});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final eCancella = testo == cancella;
    return SizedBox(
      height: 58,
      child: Material(
        color: eCancella
            ? tema.colorScheme.errorContainer.withValues(alpha: 0.55)
            : tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPremuto,
          child: Center(
            child: eCancella
                ? Icon(
                    Icons.backspace_outlined,
                    size: 24,
                    semanticLabel: 'Cancella',
                    color: tema.colorScheme.onSurface,
                  )
                : Text(
                    testo,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }
}
