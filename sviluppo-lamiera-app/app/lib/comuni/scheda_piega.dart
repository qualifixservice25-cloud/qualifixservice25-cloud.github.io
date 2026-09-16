import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import '../tema/tema.dart';
import 'tastierino.dart';

/// Cosa è stato deciso nella scheda della piega.
typedef EsitoPiega = ({PiegaProfilo? piega, bool elimina});

/// Scheda di modifica di una piega: angolo, verso, eliminazione.
///
/// Si apre toccando il badge dell'angolo sul disegno. Restituisce null se si
/// chiude senza toccare niente.
Future<EsitoPiega?> mostraSchedaPiega(
  BuildContext context, {
  required int indice,
  required PiegaProfilo piega,
  required bool eliminabile,
}) {
  return showModalBottomSheet<EsitoPiega>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SchedaPiega(
      indice: indice,
      iniziale: piega,
      eliminabile: eliminabile,
    ),
  );
}

class _SchedaPiega extends StatefulWidget {
  final int indice;
  final PiegaProfilo iniziale;
  final bool eliminabile;

  const _SchedaPiega({
    required this.indice,
    required this.iniziale,
    required this.eliminabile,
  });

  @override
  State<_SchedaPiega> createState() => _SchedaPiegaState();
}

class _SchedaPiegaState extends State<_SchedaPiega> {
  late PiegaProfilo _piega = widget.iniziale;

  static const _angoliRapidi = [30.0, 45.0, 60.0, 90.0, 120.0, 135.0];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Piega ${widget.indice + 1}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          // --- angolo -------------------------------------------------------
          Material(
            color: tema.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final v = await mostraTastierino(
                  context,
                  titolo: 'Angolo della piega ${widget.indice + 1}',
                  valore: _piega.angoloFormato,
                  unita: '°',
                  scatti: const [1, 5],
                  minimo: 1,
                  massimo: 180,
                  aiuto: 'L\'angolo che leggi sul pezzo col goniometro. '
                      '90° è la squadra, 180° è lamiera piatta.',
                );
                if (v != null) {
                  setState(() => _piega = _piega.copiaCon(angoloFormato: v));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Angolo',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      FormatoNumero.gradi(_piega.angoloFormato, decimali: 0),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.edit, size: 20,
                        color: tema.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _angoliRapidi)
                ChoiceChip(
                  label: Text(FormatoNumero.gradi(a, decimali: 0)),
                  labelStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  selected: (_piega.angoloFormato - a).abs() < 0.01,
                  onSelected: (_) => setState(
                      () => _piega = _piega.copiaCon(angoloFormato: a)),
                ),
            ],
          ),

          const SizedBox(height: 20),
          Text('VERSO',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: tema.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final v in VersoPiega.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _BottoneVerso(
                      verso: v,
                      scelto: _piega.verso == v,
                      onPremuto: () =>
                          setState(() => _piega = _piega.copiaCon(verso: v)),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'La pressa piega sempre verso l\'alto: due pieghe di verso '
              'opposto vogliono dire girare il pezzo.',
              style: TextStyle(
                fontSize: 12.5,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColoriQualifix.errore,
                    side: BorderSide(
                      color: widget.eliminabile
                          ? ColoriQualifix.errore.withValues(alpha: 0.5)
                          : tema.disabledColor.withValues(alpha: 0.3),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Elimina'),
                  onPressed: widget.eliminabile
                      ? () => Navigator.of(context)
                          .pop((piega: null, elimina: true))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pop((piega: _piega, elimina: false)),
                  child: const Text('Conferma'),
                ),
              ),
            ],
          ),
          if (!widget.eliminabile)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Un pezzo con una piega sola non può restare senza.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottoneVerso extends StatelessWidget {
  final VersoPiega verso;
  final bool scelto;
  final VoidCallback onPremuto;

  const _BottoneVerso({
    required this.verso,
    required this.scelto,
    required this.onPremuto,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final su = verso == VersoPiega.su;
    return Material(
      color: scelto
          ? ColoriQualifix.accento.withValues(alpha: 0.18)
          : tema.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPremuto,
        child: Container(
          // Come sopra: minima, non fissa.
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: scelto
                ? Border.all(color: ColoriQualifix.accento, width: 2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                su ? Icons.turn_slight_left : Icons.turn_slight_right,
                size: 26,
                color: scelto ? ColoriQualifix.accento : null,
              ),
              const SizedBox(height: 4),
              Text(
                verso.etichetta,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scelto ? ColoriQualifix.accento : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
