import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import '../comuni/widget_comuni.dart';
import '../disegno/painter_passo.dart';
import '../disegno/vista_2d.dart';
import '../stato/stato_app.dart';

/// Il parco utensili personale.
///
/// Le voci di catalogo si copiano e si modificano ma non si cancellano: chi
/// ha un utensile diverso ne crea uno suo, e il catalogo resta come
/// riferimento.
class SchermataUtensili extends StatelessWidget {
  const SchermataUtensili({super.key});

  @override
  Widget build(BuildContext context) {
    final stato = FornitoreStato.di(context);

    // Scaffold e non Column: una AppBar con `bottom` contiene a sua volta un
    // Flex, e dentro una Column riceverebbe un'altezza non limitata. Lo
    // Scaffold le passa la sua preferredSize e il problema non si pone.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Utensili'),
          bottom: const TabBar(
            labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'COLTELLI', height: 48),
              Tab(text: 'CAVE', height: 48),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ElencoPunzoni(stato: stato),
            _ElencoMatrici(stato: stato),
          ],
        ),
      ),
    );
  }
}

class _ElencoPunzoni extends StatelessWidget {
  final StatoApp stato;

  const _ElencoPunzoni({required this.stato});

  @override
  Widget build(BuildContext context) {
    final punzoni = stato.inventario.punzoniOrdinati;
    final colori = ColoriDisegno.da(Theme.of(context));

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: punzoni.length,
        itemBuilder: (context, i) {
          final p = punzoni[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              leading: SizedBox(
                width: 44,
                height: 60,
                child: CustomPaint(
                  painter: PainterUtensile(sagoma: p.sagoma, colori: colori),
                ),
              ),
              title: Text(p.nome),
              subtitle: Text(
                '${FormatoNumero.gradi(p.angoloPunta, decimali: 0)} · '
                'R${FormatoNumero.misura(p.raggioPunta, decimali: 1)} · '
                'h${FormatoNumero.misura(p.altezza, decimali: 0)} · '
                '${p.tipo.etichetta}',
                style: const TextStyle(fontSize: 13.5),
              ),
              trailing: _menu(
                context,
                diSistema: p.diSistema,
                onModifica: () => _apriScheda(context, stato, punzone: p),
                onCopia: () => _apriScheda(
                  context,
                  stato,
                  punzone: p.copiaCon(
                    id: 'mio_${DateTime.now().millisecondsSinceEpoch}',
                    nome: '${p.nome} (copia)',
                    diSistema: false,
                  ),
                ),
                onElimina: () => _confermaElimina(
                  context,
                  p.nome,
                  () => stato.eliminaPunzone(p.id),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _apriScheda(context, stato),
        icon: const Icon(Icons.add),
        label: const Text('Coltello'),
      ),
    );
  }

  void _apriScheda(BuildContext context, StatoApp stato, {Punzone? punzone}) {
    showDialog<void>(
      context: context,
      builder: (_) => _SchedaPunzone(stato: stato, iniziale: punzone),
    );
  }
}

class _ElencoMatrici extends StatelessWidget {
  final StatoApp stato;

  const _ElencoMatrici({required this.stato});

  @override
  Widget build(BuildContext context) {
    final matrici = stato.inventario.matriciOrdinate;
    final colori = ColoriDisegno.da(Theme.of(context));

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: matrici.length,
        itemBuilder: (context, i) {
          final m = matrici[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              leading: SizedBox(
                width: 44,
                height: 60,
                child: CustomPaint(
                  painter: PainterUtensile(sagoma: m.sagoma, colori: colori),
                ),
              ),
              title: Text(m.nome),
              subtitle: Text(
                'V${FormatoNumero.misura(m.aperturaV, decimali: 0)} · '
                '${FormatoNumero.gradi(m.angoloV, decimali: 0)} · '
                'spalla R${FormatoNumero.misura(m.raggioSpalla, decimali: 1)} · '
                'profonda ${FormatoNumero.mm(m.profondita)}',
                style: const TextStyle(fontSize: 13.5),
              ),
              trailing: _menu(
                context,
                diSistema: m.diSistema,
                onModifica: () => _apriScheda(context, stato, matrice: m),
                onCopia: () => _apriScheda(
                  context,
                  stato,
                  matrice: m.copiaCon(
                    id: 'mia_${DateTime.now().millisecondsSinceEpoch}',
                    nome: '${m.nome} (copia)',
                    diSistema: false,
                  ),
                ),
                onElimina: () => _confermaElimina(
                  context,
                  m.nome,
                  () => stato.eliminaMatrice(m.id),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _apriScheda(context, stato),
        icon: const Icon(Icons.add),
        label: const Text('Cava'),
      ),
    );
  }

  void _apriScheda(BuildContext context, StatoApp stato, {Matrice? matrice}) {
    showDialog<void>(
      context: context,
      builder: (_) => _SchedaMatrice(stato: stato, iniziale: matrice),
    );
  }
}

Widget _menu(
  BuildContext context, {
  required bool diSistema,
  required VoidCallback onModifica,
  required VoidCallback onCopia,
  required VoidCallback onElimina,
}) {
  return PopupMenuButton<String>(
    iconSize: 26,
    onSelected: (scelta) => switch (scelta) {
      'modifica' => onModifica(),
      'copia' => onCopia(),
      _ => onElimina(),
    },
    itemBuilder: (context) => [
      if (!diSistema)
        const PopupMenuItem(value: 'modifica', child: Text('Modifica')),
      const PopupMenuItem(value: 'copia', child: Text('Duplica e modifica')),
      if (!diSistema)
        const PopupMenuItem(value: 'elimina', child: Text('Elimina')),
      if (diSistema)
        const PopupMenuItem(
          enabled: false,
          value: 'info',
          child: Text('Voce di catalogo'),
        ),
    ],
  );
}

void _confermaElimina(
  BuildContext context,
  String nome,
  VoidCallback onConferma,
) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminare?'),
      content: Text('«$nome» verrà tolto dal tuo inventario.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            onConferma();
            Navigator.of(context).pop();
          },
          child: const Text('Elimina'),
        ),
      ],
    ),
  );
}

// --- schede di modifica ----------------------------------------------------

class _SchedaPunzone extends StatefulWidget {
  final StatoApp stato;
  final Punzone? iniziale;

  const _SchedaPunzone({required this.stato, this.iniziale});

  @override
  State<_SchedaPunzone> createState() => _SchedaPunzoneState();
}

class _SchedaPunzoneState extends State<_SchedaPunzone> {
  late String _nome = widget.iniziale?.nome ?? 'Coltello mio';
  late double _angolo = widget.iniziale?.angoloPunta ?? 88;
  late double _raggio = widget.iniziale?.raggioPunta ?? 0.8;
  late double _altezza = widget.iniziale?.altezza ?? 120;
  late double _larghezza = widget.iniziale?.larghezzaCorpo ?? 26;
  late double _carico = widget.iniziale?.caricoMaxKnPerMetro ?? 1000;
  late TipoPunzone _tipo = widget.iniziale?.tipo ?? TipoPunzone.standard;
  late double _gollaProfondita = widget.iniziale?.gollaProfondita ?? 16;
  late double _gollaAltezza = widget.iniziale?.gollaAltezza ?? 45;

  Punzone get _costruito => Punzone(
        id: widget.iniziale?.id ??
            'mio_${DateTime.now().millisecondsSinceEpoch}',
        nome: _nome,
        angoloPunta: _angolo,
        raggioPunta: _raggio,
        altezza: _altezza,
        larghezzaCorpo: _larghezza,
        caricoMaxKnPerMetro: _carico,
        tipo: _tipo,
        gollaProfondita: _gollaProfondita,
        gollaAltezza: _gollaAltezza,
        diSistema: false,
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.iniziale == null ? 'Nuovo coltello' : 'Coltello'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 120,
                child: CustomPaint(
                  painter: PainterUtensile(
                    sagoma: _costruito.sagoma,
                    colori: ColoriDisegno.da(Theme.of(context)),
                  ),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _nome,
                decoration: const InputDecoration(labelText: 'Nome'),
                onChanged: (v) => setState(() => _nome = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TipoPunzone>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final t in TipoPunzone.values)
                    DropdownMenuItem(value: t, child: Text(t.etichetta)),
                ],
                onChanged: (t) => setState(() => _tipo = t ?? _tipo),
              ),
              const SizedBox(height: 12),
              _coppia(
                CampoNumerico(
                  etichetta: 'Angolo punta',
                  suffisso: '°',
                  valore: _angolo,
                  onCambiato: (v) => setState(() => _angolo = v ?? _angolo),
                ),
                CampoNumerico(
                  etichetta: 'Raggio punta',
                  valore: _raggio,
                  onCambiato: (v) => setState(() => _raggio = v ?? _raggio),
                ),
              ),
              const SizedBox(height: 12),
              _coppia(
                CampoNumerico(
                  etichetta: 'Altezza',
                  valore: _altezza,
                  onCambiato: (v) => setState(() => _altezza = v ?? _altezza),
                ),
                CampoNumerico(
                  etichetta: 'Larghezza fusto',
                  valore: _larghezza,
                  onCambiato: (v) =>
                      setState(() => _larghezza = v ?? _larghezza),
                ),
              ),
              if (_tipo == TipoPunzone.colloDoca) ...[
                const SizedBox(height: 12),
                _coppia(
                  CampoNumerico(
                    etichetta: 'Golla: profondità',
                    valore: _gollaProfondita,
                    onCambiato: (v) =>
                        setState(() => _gollaProfondita = v ?? _gollaProfondita),
                  ),
                  CampoNumerico(
                    etichetta: 'Golla: altezza',
                    valore: _gollaAltezza,
                    onCambiato: (v) =>
                        setState(() => _gollaAltezza = v ?? _gollaAltezza),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              CampoNumerico(
                etichetta: 'Carico massimo',
                suffisso: 'kN/m',
                valore: _carico,
                onCambiato: (v) => setState(() => _carico = v ?? _carico),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            widget.stato.salvaPunzone(_costruito);
            Navigator.of(context).pop();
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

class _SchedaMatrice extends StatefulWidget {
  final StatoApp stato;
  final Matrice? iniziale;

  const _SchedaMatrice({required this.stato, this.iniziale});

  @override
  State<_SchedaMatrice> createState() => _SchedaMatriceState();
}

class _SchedaMatriceState extends State<_SchedaMatrice> {
  late String _nome = widget.iniziale?.nome ?? 'Cava mia';
  late double _apertura = widget.iniziale?.aperturaV ?? 16;
  late double _angolo = widget.iniziale?.angoloV ?? 85;
  late double _spalla = widget.iniziale?.raggioSpalla ?? 1.5;
  late double _altezza = widget.iniziale?.altezza ?? 60;
  late double _carico = widget.iniziale?.caricoMaxKnPerMetro ?? 1000;

  Matrice get _costruita => Matrice(
        id: widget.iniziale?.id ??
            'mia_${DateTime.now().millisecondsSinceEpoch}',
        nome: _nome,
        aperturaV: _apertura,
        angoloV: _angolo,
        raggioSpalla: _spalla,
        altezza: _altezza,
        caricoMaxKnPerMetro: _carico,
        diSistema: false,
      );

  @override
  Widget build(BuildContext context) {
    final costruita = _costruita;
    return AlertDialog(
      title: Text(widget.iniziale == null ? 'Nuova cava' : 'Cava'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 120,
                child: CustomPaint(
                  painter: PainterUtensile(
                    sagoma: costruita.sagoma,
                    colori: ColoriDisegno.da(Theme.of(context)),
                  ),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Profondità ${FormatoNumero.mm(costruita.profondita)} · '
                'lato minimo ${FormatoNumero.mm(LatoMinimo.praticoDaV(
                  _apertura,
                  coefficiente: widget.stato.impostazioni.latoMinimo.coefficiente,
                ))}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _nome,
                decoration: const InputDecoration(labelText: 'Nome'),
                onChanged: (v) => setState(() => _nome = v),
              ),
              const SizedBox(height: 12),
              _coppia(
                CampoNumerico(
                  etichetta: 'Apertura V',
                  valore: _apertura,
                  onCambiato: (v) => setState(() => _apertura = v ?? _apertura),
                ),
                CampoNumerico(
                  etichetta: 'Angolo V',
                  suffisso: '°',
                  valore: _angolo,
                  onCambiato: (v) => setState(() => _angolo = v ?? _angolo),
                ),
              ),
              const SizedBox(height: 12),
              _coppia(
                CampoNumerico(
                  etichetta: 'Raggio spalla',
                  valore: _spalla,
                  onCambiato: (v) => setState(() => _spalla = v ?? _spalla),
                ),
                CampoNumerico(
                  etichetta: 'Altezza',
                  valore: _altezza,
                  onCambiato: (v) => setState(() => _altezza = v ?? _altezza),
                ),
              ),
              const SizedBox(height: 12),
              CampoNumerico(
                etichetta: 'Carico massimo',
                suffisso: 'kN/m',
                valore: _carico,
                onCambiato: (v) => setState(() => _carico = v ?? _carico),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            widget.stato.salvaMatrice(costruita);
            Navigator.of(context).pop();
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

Widget _coppia(Widget sinistra, Widget destra) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: sinistra),
        const SizedBox(width: 10),
        Expanded(child: destra),
      ],
    );
