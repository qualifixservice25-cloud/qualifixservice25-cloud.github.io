import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import '../comuni/widget_comuni.dart';
import '../stato/stato_app.dart';
import '../tema/tema.dart';

/// La versione mostrata all'utente.
///
/// Serve per sapere quale build è viva: la versione web viene messa in cache
/// dal service worker e dopo un aggiornamento può servire un ricaricamento.
const String versioneApp = '1.0.0';

class SchermataImpostazioni extends StatelessWidget {
  const SchermataImpostazioni({super.key});

  @override
  Widget build(BuildContext context) {
    final stato = FornitoreStato.di(context);
    final impostazioni = stato.impostazioni;

    return Column(
      children: [
        AppBar(title: const Text('Impostazioni')),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const TitoloSezione('SCHERMO'),
              Card(
                child: SwitchListTile(
                  title: const Text('Modalità officina'),
                  subtitle: const Text(
                    'Tema scuro ad alto contrasto e testo più grande, per '
                    'lavorare accanto alla macchina.',
                    style: TextStyle(fontSize: 13.5),
                  ),
                  value: impostazioni.modalitaOfficina,
                  onChanged: (v) => stato.aggiornaImpostazioni(
                    impostazioni.copiaCon(modalitaOfficina: v),
                  ),
                ),
              ),

              const TitoloSezione('TARATURA SUL TUO ACCIAIO'),
              _Taratura(stato: stato),

              const TitoloSezione('LATO MINIMO'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CampoNumerico(
                        etichetta: 'Coefficiente della regola',
                        suffisso: '× V',
                        valore: impostazioni.latoMinimo.coefficiente,
                        aiuto: 'Con V16 questa regola dà '
                            '${FormatoNumero.mm(LatoMinimo.praticoDaV(16, coefficiente: impostazioni.latoMinimo.coefficiente))}. '
                            'Le tabelle costruttore indicano circa 11 mm: '
                            'alza il coefficiente a 0,69 per allinearti ai tuoi '
                            'utensili.',
                        onCambiato: (v) {
                          if (v == null || v <= 0) return;
                          stato.aggiornaImpostazioni(
                            impostazioni.copiaCon(
                              latoMinimo: impostazioni.latoMinimo
                                  .copiaCon(coefficiente: v),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Usa la variante geometrica'),
                        subtitle: const Text(
                          'Calcola il minimo dalla spalla della cava e '
                          'dall\'angolo invece che dalla regola pratica.',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: impostazioni.latoMinimo.usaVarianteGeometrica,
                        onChanged: (v) => stato.aggiornaImpostazioni(
                          impostazioni.copiaCon(
                            latoMinimo: impostazioni.latoMinimo
                                .copiaCon(usaVarianteGeometrica: v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const TitoloSezione('CONTROLLO COLLISIONI'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CampoNumerico(
                        etichetta: 'Gioco minimo',
                        valore: impostazioni.giocoMinimo,
                        aiuto: 'Sotto questa distanza dal coltello si parla di '
                            'collisione.',
                        onCambiato: (v) {
                          if (v == null || v < 0) return;
                          stato.aggiornaImpostazioni(
                            impostazioni.copiaCon(giocoMinimo: v),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      CampoNumerico(
                        etichetta: 'Gioco desiderato',
                        valore: impostazioni.giocoDesiderato,
                        aiuto: 'Sotto questa distanza la sequenza viene '
                            'penalizzata, ma resta possibile.',
                        onCambiato: (v) {
                          if (v == null || v < 0) return;
                          stato.aggiornaImpostazioni(
                            impostazioni.copiaCon(giocoDesiderato: v),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const TitoloSezione('VISUALIZZAZIONE'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Decimali delle lunghezze')),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('0')),
                          ButtonSegment(value: 1, label: Text('1')),
                          ButtonSegment(value: 2, label: Text('2')),
                        ],
                        selected: {impostazioni.decimaliLunghezza},
                        onSelectionChanged: (s) => stato.aggiornaImpostazioni(
                          impostazioni.copiaCon(decimaliLunghezza: s.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const TitoloSezione('INVENTARIO'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('Ripristina il catalogo'),
                      subtitle: const Text(
                        'Rimette le cave e i coltelli di serie che mancano. '
                        'Non tocca quelli che hai aggiunto o modificato.',
                        style: TextStyle(fontSize: 13.5),
                      ),
                      onTap: () async {
                        await stato.ripristinaCatalogo();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Catalogo ripristinato')),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(
                        '${stato.inventario.punzoni.length} coltelli · '
                        '${stato.inventario.matrici.length} cave',
                      ),
                      subtitle: const Text(
                        'I tuoi utensili sono salvati solo su questo '
                        'dispositivo. Se cancelli i dati del sito o del '
                        'browser, spariscono.',
                        style: TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),

              const TitoloSezione('COSA NON FA QUESTA APP'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final limite in [
                        'Non calcola il ritorno elastico: gli angoli mostrati '
                            'sono quelli a fondo corsa, non quelli del pezzo '
                            'una volta rilasciato.',
                        'Non calcola il tonnellaggio né verifica il carico '
                            'della pressa.',
                        'Non calcola le battute posteriori.',
                        // Il ritorno elastico è già detto sopra, e meglio: si
                        // toglie il doppione invece di ripeterlo all'utente.
                        ...RilevatoreCollisioni.limitiNoti.where(
                          (l) => !l.contains('ritorno elastico'),
                        ),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('· '),
                              Expanded(
                                child: Text(
                                  limite,
                                  style: const TextStyle(
                                      fontSize: 13.5, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Sviluppo Lamiera $versioneApp',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qualifix Service',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// La taratura da provino: da «fidati della formula» a «fidati del tuo
/// acciaio».
class _Taratura extends StatefulWidget {
  final StatoApp stato;

  const _Taratura({required this.stato});

  @override
  State<_Taratura> createState() => _TaraturaState();
}

class _TaraturaState extends State<_Taratura> {
  double? _misurato;
  String? _esito;
  bool _riuscita = false;

  @override
  Widget build(BuildContext context) {
    final stato = widget.stato;
    final materiale = stato.profilo.materiale;
    final sviluppo = stato.sviluppo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Piega un provino con le misure del pezzo che hai impostato, '
              'misura lo sviluppo che ti è servito davvero e scrivilo qui: '
              'l\'app ricava il fattore K della tua macchina con '
              '${materiale.nome}.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (sviluppo.eAttendibile)
              Text(
                'Sviluppo calcolato ora: '
                '${FormatoNumero.mm(sviluppo.lunghezzaTotale, decimali: 2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const Text(
                'Imposta prima un pezzo calcolabile nella scheda Sviluppo.',
                style: TextStyle(fontSize: 14, color: ColoriQualifix.errore),
              ),
            const SizedBox(height: 12),
            CampoNumerico(
              etichetta: 'Sviluppo misurato sul provino',
              valore: _misurato,
              abilitato: sviluppo.eAttendibile,
              onCambiato: (v) => setState(() {
                _misurato = v;
                _esito = null;
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.tune),
                    label: const Text('Tara'),
                    onPressed: (_misurato == null || !sviluppo.eAttendibile)
                        ? null
                        : () async {
                            final ok =
                                await stato.taraSuSviluppoMisurato(_misurato!);
                            if (!context.mounted) return;
                            setState(() {
                              _riuscita = ok;
                              _esito = ok
                                  ? 'Taratura salvata su ${materiale.nome}.'
                                  : 'Quella misura non è compatibile con questa '
                                      'cava e questo spessore: controlla il '
                                      'provino e le quote inserite.';
                            });
                          },
                  ),
                ),
                if (materiale.eTarato) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      await stato.azzeraTaratura();
                      if (!context.mounted) return;
                      setState(() {
                        _esito = 'Taratura azzerata: si torna al DIN 6935.';
                        _riuscita = true;
                      });
                    },
                    child: const Text('Azzera'),
                  ),
                ],
              ],
            ),
            if (materiale.eTarato)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: BannerAvvertimenti(avvertimenti: [
                  Avvertimento.informazione(
                    CodiceAvvertimento.kTarato,
                    '${materiale.nome} è tarato con un fattore '
                    '×${FormatoNumero.fattore(materiale.correzioneK)} '
                    'rispetto al DIN 6935.',
                  ),
                ]),
              ),
            if (_esito != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _esito!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _riuscita
                        ? ColoriQualifix.successo
                        : ColoriQualifix.errore,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
