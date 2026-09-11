import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import '../comuni/widget_comuni.dart';
import '../stato/stato_app.dart';
import '../tema/tema.dart';

/// Il calcolatore della singola piega.
///
/// È la schermata che insegna: fa vedere passo per passo come dalla cava si
/// arriva alla detrazione, così chi conosce il mestiere può controllare ogni
/// anello con la propria esperienza invece di fidarsi di un numero nudo.
class SchermataPiega extends StatefulWidget {
  const SchermataPiega({super.key});

  @override
  State<SchermataPiega> createState() => _SchermataPiegaState();
}

class _SchermataPiegaState extends State<SchermataPiega> {
  double _angolo = 90;

  @override
  Widget build(BuildContext context) {
    final stato = FornitoreStato.di(context);
    final profilo = stato.profilo;
    final matrice = stato.inventario.matricePerId(profilo.idMatricePredefinita);

    final risultato = matrice == null
        ? null
        : CalcoloPiega.calcola(ParametriPiega(
            spessore: profilo.spessore,
            angoloFormato: _angolo,
            aperturaV: matrice.aperturaV,
            materiale: profilo.materiale,
          ));

    return Column(
      children: [
        AppBar(
          title: const Text('Piega'),
          actions: [
            IconButton(
              tooltip: 'Come funziona',
              icon: const Icon(Icons.help_outline),
              onPressed: () => _mostraSpiegazione(context),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _selettoreMateriale(stato),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: CampoNumerico(
                      etichetta: 'Spessore',
                      valore: profilo.spessore,
                      onCambiato: (v) {
                        if (v != null && v > 0) stato.impostaSpessore(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CampoNumerico(
                      etichetta: 'Angolo',
                      suffisso: '°',
                      valore: _angolo,
                      onCambiato: (v) {
                        if (v != null) setState(() => _angolo = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _selettoreCava(stato, matrice),
              const SizedBox(height: 8),
              _angoliRapidi(),

              if (risultato == null)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: BannerAvvertimenti(avvertimenti: [
                    Avvertimento.errore(
                      CodiceAvvertimento.nessunaCavaAdatta,
                      'Scegli una cava dal tuo inventario per calcolare la '
                      'piega. Senza, non c\'è nessun raggio da cui partire.',
                    ),
                  ]),
                )
              else ...[
                const SizedBox(height: 20),
                SchedaRisultato(
                  titolo: 'Detrazione (cala)',
                  valore: FormatoNumero.mm(risultato.bd, decimali: 2),
                  sottotitolo: '≈ ${FormatoNumero.fattore(risultato.bdInSpessori, decimali: 2)}'
                      ' × lo spessore'
                      '${_notaRegola(risultato)}',
                  icona: Icons.content_cut,
                ),
                Row(
                  children: [
                    Expanded(
                      child: SchedaRisultato(
                        titolo: 'Raggio interno',
                        valore: FormatoNumero.mm(risultato.raggioInterno, decimali: 2),
                        sottotitolo: 'prodotto dalla cava',
                        colore: ColoriQualifix.accento,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SchedaRisultato(
                        titolo: 'Fattore K',
                        valore: FormatoNumero.fattore(risultato.fattoreK),
                        sottotitolo: risultato.origineK.etichetta,
                        colore: ColoriQualifix.successo,
                      ),
                    ),
                  ],
                ),
                const TitoloSezione('COME CI SI ARRIVA'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Column(
                      children: [
                        for (final passo in risultato.catena) ...[
                          RigaCatena(passo: passo),
                          if (passo != risultato.catena.last)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                ),
                if (risultato.avvertimenti.isNotEmpty) ...[
                  const TitoloSezione('DA VERIFICARE'),
                  BannerAvvertimenti(avvertimenti: risultato.avvertimenti),
                ],
                const AvvisoProvino(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _notaRegola(RisultatoPiega r) {
    final rapportoCava = r.aperturaV / r.spessore;
    if ((rapportoCava - 8).abs() < 0.3 && (r.angoloFormato - 90).abs() < 0.5) {
      return ' — con V = 8×S a 90° la regola d\'officina dice 2×S';
    }
    return '';
  }

  Widget _selettoreMateriale(StatoApp stato) {
    return DropdownButtonFormField<String>(
      initialValue: stato.profilo.materiale.id,
      decoration: const InputDecoration(labelText: 'Materiale'),
      style: const TextStyle(fontSize: TemaApp.corpoTesto),
      items: [
        for (final m in stato.materiali)
          DropdownMenuItem(
            value: m.id,
            child: Text(
              m.eTarato ? '${m.nome} · tarato' : m.nome,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) {
        final materiale = stato.materiali.firstWhere((m) => m.id == id);
        stato.aggiornaProfilo(stato.profilo.copiaCon(materiale: materiale));
      },
    );
  }

  Widget _selettoreCava(StatoApp stato, Matrice? scelta) {
    final adatte = RegolaMatrice.compatibili(stato.inventario, stato.profilo.spessore);
    final consigliata = RegolaMatrice.vConsigliata(stato.profilo.spessore);

    return DropdownButtonFormField<String>(
      initialValue: scelta?.id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Cava',
        helperText: 'Per ${FormatoNumero.mm(stato.profilo.spessore)} si '
            'consiglia V${FormatoNumero.misura(consigliata, decimali: 0)}',
      ),
      style: const TextStyle(fontSize: TemaApp.corpoTesto),
      items: [
        for (final m in stato.inventario.matriciOrdinate)
          DropdownMenuItem(
            value: m.id,
            child: Text(
              adatte.contains(m) ? m.nome : '${m.nome}  (fuori regola)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) => stato.aggiornaProfilo(
        stato.profilo.copiaCon(idMatricePredefinita: id),
      ),
    );
  }

  Widget _angoliRapidi() {
    const angoli = [30.0, 45.0, 60.0, 90.0, 120.0, 135.0];
    return Wrap(
      spacing: 8,
      children: [
        for (final a in angoli)
          ChoiceChip(
            label: Text(FormatoNumero.gradi(a, decimali: 0)),
            selected: (_angolo - a).abs() < 0.01,
            onSelected: (_) => setState(() => _angolo = a),
          ),
      ],
    );
  }

  void _mostraSpiegazione(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('La catena della piega in aria'),
        content: const SingleChildScrollView(
          child: Text(
            'In piega in aria il raggio interno non si sceglie: lo produce la '
            'cava.\n\n'
            'Ri = c · V  →  il rapporto Ri/S  →  il fattore K secondo DIN 6935 '
            '→  abbuono, sporgenza e detrazione  →  lo sviluppo.\n\n'
            'L\'app mostra ogni anello invece del solo risultato, così puoi '
            'controllarli con la tua esperienza: se il raggio non ti torna, il '
            'numero finale è sbagliato e te ne accorgi prima di tagliare.\n\n'
            'I coefficienti sono valori tipici. Per farli diventare i numeri '
            'della tua macchina, usa la taratura da provino in Impostazioni.',
            style: TextStyle(fontSize: 15, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ho capito'),
          ),
        ],
      ),
    );
  }
}
