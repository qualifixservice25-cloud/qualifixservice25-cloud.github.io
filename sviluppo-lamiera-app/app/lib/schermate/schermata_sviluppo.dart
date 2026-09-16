import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import '../comuni/scheda_piega.dart';
import '../comuni/tastierino.dart';
import '../comuni/widget_comuni.dart';
import '../disegno/painter_profilo.dart';
import '../disegno/vista_2d.dart';
import '../disegno/zone_tocco.dart';
import '../stato/stato_app.dart';
import '../tema/tema.dart';

/// Il pezzo e la sua lunghezza da tagliare.
///
/// Il disegno non è un'anteprima: è l'editor. Le quote e gli angoli scritti sul
/// profilo sono pulsanti — si tocca il numero e si cambia il numero. I «+» alle
/// estremità aggiungono un lato, e toccando una piega la si può togliere.
class SchermataSviluppo extends StatefulWidget {
  const SchermataSviluppo({super.key});

  @override
  State<SchermataSviluppo> createState() => _SchermataSviluppoState();
}

class _SchermataSviluppoState extends State<SchermataSviluppo> {
  /// Riempita dal painter a ogni disegno, interrogata al tocco.
  final List<ZonaTocco> _zone = [];

  /// Le aree toccabili dell'ultimo disegno. Esposta perché i test possano
  /// toccare esattamente dove sta un comando, invece di indovinare i pixel.
  @visibleForTesting
  List<ZonaTocco> get zone => List.unmodifiable(_zone);

  @override
  Widget build(BuildContext context) {
    final stato = FornitoreStato.di(context);
    final sviluppo = stato.sviluppo;

    return Column(
      children: [
        AppBar(
          title: const Text('Sviluppo'),
          actions: [
            IconButton(
              tooltip: 'Come si modifica',
              icon: const Icon(Icons.help_outline),
              onPressed: _mostraAiuto,
            ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, vincoli) {
              final affiancato = vincoli.maxWidth >= 900;
              if (!affiancato) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                  children: [
                    _risultato(stato, sviluppo),
                    const SizedBox(height: 12),
                    _riquadro(stato, altezza: math.max(340, vincoli.maxHeight * 0.48)),
                    const SizedBox(height: 12),
                    _pastiglie(stato),
                    ..._dettagli(stato, sviluppo),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
                      child: Column(
                        children: [
                          Expanded(child: _riquadro(stato)),
                          const SizedBox(height: 12),
                          _pastiglie(stato),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 10, 16, 32),
                      children: [
                        _risultato(stato, sviluppo),
                        ..._dettagli(stato, sviluppo),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // --- il risultato --------------------------------------------------------

  Widget _risultato(StatoApp stato, RisultatoSviluppo sviluppo) {
    return SchedaRisultato(
      titolo: 'Lunghezza da tagliare',
      valore: sviluppo.eAttendibile
          ? FormatoNumero.mm(
              sviluppo.lunghezzaTotale,
              decimali: stato.impostazioni.decimaliLunghezza,
            )
          : '—',
      sottotitolo: sviluppo.eAttendibile
          ? 'quote inserite ${FormatoNumero.mm(sviluppo.sommaQuoteInserite)} '
              '− detrazioni ${FormatoNumero.mm(sviluppo.sommaDetrazioni)}'
          : 'manca un dato: vedi gli avvisi in fondo',
      icona: Icons.straighten,
      colore: sviluppo.eAttendibile ? null : ColoriQualifix.errore,
    );
  }

  // --- il riquadro che si modifica ----------------------------------------

  Widget _riquadro(StatoApp stato, {double? altezza}) {
    final disegno = _disegno(stato);
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: disegno == null
          ? const Center(child: Text('Profilo non valido'))
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _tocco(stato, d.localPosition),
              child: CustomPaint(
                painter: PainterProfilo(
                  geometria: disegno.geometria,
                  profilo: stato.profilo,
                  quote: disegno.quote,
                  colori: ColoriDisegno.da(Theme.of(context)),
                  zone: _zone,
                ),
                size: Size.infinite,
              ),
            ),
    );
    return altezza == null ? card : SizedBox(height: altezza, child: card);
  }

  /// Geometria da disegnare e quote da scriverci sopra.
  ///
  /// Quando lo sviluppo non è attendibile — tipicamente perché manca la cava —
  /// il disegno si costruisce lo stesso, con la cava consigliata per lo
  /// spessore. Senza, nel momento in cui il calcolo si ferma non si potrebbe
  /// più correggere il pezzo, che è proprio quando serve.
  ({GeometriaProfilo geometria, List<double> quote})? _disegno(StatoApp stato) {
    final profilo = stato.profilo;
    if (!profilo.haStrutturaValida || profilo.spessore <= 0) return null;

    final sviluppo = stato.sviluppo;
    final List<RisultatoPiega> pieghe;
    final List<double> trattiPiani;

    if (sviluppo.eAttendibile) {
      pieghe = sviluppo.pieghe;
      trattiPiani = sviluppo.trattiPiani;
    } else {
      final v = RegolaMatrice.vConsigliata(profilo.spessore);
      pieghe = [
        for (final p in profilo.pieghe)
          CalcoloPiega.calcola(ParametriPiega(
            spessore: profilo.spessore,
            angoloFormato: p.angoloFormato,
            aperturaV: v,
            materiale: profilo.materiale,
          )),
      ];
      trattiPiani = [for (final t in profilo.tratti) t.lunghezza];
    }

    return (
      geometria: CostruttoreGeometria.costruisci(
        profilo: profilo,
        trattiPiani: trattiPiani,
        pieghe: pieghe,
      ),
      quote: [for (final t in profilo.tratti) t.lunghezza],
    );
  }

  Future<void> _tocco(StatoApp stato, Offset punto) async {
    // A ritroso: i «+» sono disegnati per ultimi e devono vincere in caso di
    // sovrapposizione con una quota vicina.
    for (final zona in _zone.reversed) {
      if (!zona.area.contains(punto)) continue;
      switch (zona.tipo) {
        case TipoZona.lato:
          await _modificaLato(stato, zona.indice);
        case TipoZona.piega:
          await _modificaPiega(stato, zona.indice);
        case TipoZona.aggiungiInizio:
          stato.aggiornaProfilo(stato.profilo.conTrattoInTesta());
        case TipoZona.aggiungiFine:
          stato.aggiornaProfilo(stato.profilo.conTrattoAggiunto());
      }
      return;
    }
  }

  Future<void> _modificaLato(StatoApp stato, int indice) async {
    final profilo = stato.profilo;
    if (indice < 0 || indice >= profilo.tratti.length) return;
    final tratto = profilo.tratti[indice];

    final valore = await mostraTastierino(
      context,
      titolo: 'Tratto ${tratto.etichetta}',
      valore: tratto.lunghezza,
      minimo: 0.1,
      aiuto: profilo.quotatura == QuotaturaProfilo.esterna
          ? 'Misura presa sul filo esterno.'
          : 'Tratto piano, da tangente a tangente.',
    );
    if (valore == null) return;

    final nuovi = [...profilo.tratti];
    nuovi[indice] = tratto.copiaCon(lunghezza: valore);
    stato.aggiornaProfilo(profilo.copiaCon(tratti: nuovi));
  }

  Future<void> _modificaPiega(StatoApp stato, int indice) async {
    final profilo = stato.profilo;
    if (indice < 0 || indice >= profilo.pieghe.length) return;

    final esito = await mostraSchedaPiega(
      context,
      indice: indice,
      piega: profilo.pieghe[indice],
      eliminabile: profilo.pieghe.length > 1,
    );
    if (esito == null) return;

    if (esito.elimina) {
      stato.aggiornaProfilo(profilo.senzaPiega(indice));
      return;
    }
    if (esito.piega != null) {
      final nuove = [...profilo.pieghe];
      nuove[indice] = esito.piega!;
      stato.aggiornaProfilo(profilo.copiaCon(pieghe: nuove));
    }
  }

  // --- le tre pastiglie ----------------------------------------------------

  Widget _pastiglie(StatoApp stato) {
    final profilo = stato.profilo;
    final cava = stato.inventario.matricePerId(profilo.idMatricePredefinita);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _Pastiglia(
            etichetta: 'Materiale',
            valore: profilo.materiale.nome,
            onPremuto: () => _scegliMateriale(stato),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _Pastiglia(
            etichetta: 'Spessore',
            valore: FormatoNumero.mm(profilo.spessore),
            onPremuto: () async {
              final v = await mostraTastierino(
                context,
                titolo: 'Spessore della lamiera',
                valore: profilo.spessore,
                minimo: 0.1,
                massimo: 50,
                scatti: const [0.1, 0.5],
              );
              if (v != null) stato.impostaSpessore(v);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _Pastiglia(
            etichetta: 'Cava',
            valore: cava?.nome ?? 'da scegliere',
            allarme: cava == null,
            onPremuto: () => _scegliCava(stato),
          ),
        ),
      ],
    );
  }

  Future<void> _scegliMateriale(StatoApp stato) async {
    final scelto = await showModalBottomSheet<Materiale>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final m in stato.materiali)
            ListTile(
              title: Text(m.eTarato ? '${m.nome} · tarato' : m.nome),
              subtitle: Text('${m.famiglia} · c = '
                  '${FormatoNumero.fattore(m.coefficienteRaggio)}'),
              selected: m.id == stato.profilo.materiale.id,
              onTap: () => Navigator.of(context).pop(m),
            ),
        ],
      ),
    );
    if (scelto != null) {
      stato.aggiornaProfilo(stato.profilo.copiaCon(materiale: scelto));
    }
  }

  Future<void> _scegliCava(StatoApp stato) async {
    final spessore = stato.profilo.spessore;
    final adatte = RegolaMatrice.compatibili(stato.inventario, spessore);
    final consigliata = RegolaMatrice.vConsigliata(spessore);

    final scelta = await showModalBottomSheet<Matrice>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Per ${FormatoNumero.mm(spessore)} si consiglia la '
              'V${FormatoNumero.misura(consigliata, decimali: 0)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          for (final m in stato.inventario.matriciOrdinate)
            ListTile(
              title: Text(m.nome),
              subtitle: Text(adatte.contains(m)
                  ? 'lato minimo ${FormatoNumero.mm(LatoMinimo.praticoDaV(m.aperturaV, coefficiente: stato.impostazioni.latoMinimo.coefficiente))}'
                  : 'fuori regola per questo spessore'),
              enabled: true,
              selected: m.id == stato.profilo.idMatricePredefinita,
              leading: Icon(
                adatte.contains(m) ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                color: adatte.contains(m)
                    ? ColoriQualifix.successo
                    : ColoriQualifix.attenzione,
              ),
              onTap: () => Navigator.of(context).pop(m),
            ),
        ],
      ),
    );
    if (scelta != null) {
      stato.aggiornaProfilo(
          stato.profilo.copiaCon(idMatricePredefinita: scelta.id));
    }
  }

  // --- il resto ------------------------------------------------------------

  List<Widget> _dettagli(StatoApp stato, RisultatoSviluppo sviluppo) {
    final profilo = stato.profilo;
    return [
      const TitoloSezione('COME HAI QUOTATO IL DISEGNO'),
      SegmentedButton<QuotaturaProfilo>(
        segments: const [
          ButtonSegment(
            value: QuotaturaProfilo.esterna,
            label: Text('Quote esterne'),
            icon: Icon(Icons.crop_free),
          ),
          ButtonSegment(
            value: QuotaturaProfilo.interna,
            label: Text('Tratti piani'),
            icon: Icon(Icons.straighten),
          ),
        ],
        selected: {profilo.quotatura},
        onSelectionChanged: (s) => stato.aggiornaProfilo(
          profilo.copiaCon(quotatura: s.first),
        ),
      ),
      if (sviluppo.eAttendibile) ...[
        const TitoloSezione('LA LAMIERA DA TAGLIARE'),
        Card(
          child: SizedBox(
            height: 130,
            child: CustomPaint(
              painter: PainterSviluppo(
                sviluppo: sviluppo,
                spessore: profilo.spessore,
                colori: ColoriDisegno.da(Theme.of(context)),
              ),
              size: Size.infinite,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            'I numeri in arancione sono le righe da tracciare sul pezzo, '
            'misurate dal bordo iniziale.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const TitoloSezione('DETTAGLIO PER PIEGA'),
        _tabellaPieghe(sviluppo),
      ],
      if (sviluppo.avvertimenti.isNotEmpty) ...[
        const TitoloSezione('DA VERIFICARE'),
        BannerAvvertimenti(avvertimenti: sviluppo.avvertimenti),
      ],
      const AvvisoProvino(),
    ];
  }

  Widget _tabellaPieghe(RisultatoSviluppo sviluppo) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 22,
          headingTextStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          dataTextStyle: const TextStyle(
            fontSize: 14,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          columns: const [
            DataColumn(label: Text('N.')),
            DataColumn(label: Text('Angolo')),
            DataColumn(label: Text('Ri')),
            DataColumn(label: Text('K')),
            DataColumn(label: Text('Abbuono')),
            DataColumn(label: Text('Detrazione')),
          ],
          rows: [
            for (var i = 0; i < sviluppo.pieghe.length; i++)
              DataRow(cells: [
                DataCell(Text('${i + 1}')),
                DataCell(Text(FormatoNumero.gradi(
                    sviluppo.pieghe[i].angoloFormato,
                    decimali: 0))),
                DataCell(Text(FormatoNumero.misura(
                    sviluppo.pieghe[i].raggioInterno,
                    decimali: 2))),
                DataCell(
                    Text(FormatoNumero.fattore(sviluppo.pieghe[i].fattoreK))),
                DataCell(Text(
                    FormatoNumero.misura(sviluppo.pieghe[i].ba, decimali: 2))),
                DataCell(Text(
                    FormatoNumero.misura(sviluppo.pieghe[i].bd, decimali: 2))),
              ]),
          ],
        ),
      ),
    );
  }

  void _mostraAiuto() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Si modifica dal disegno'),
        content: const SingleChildScrollView(
          child: Text(
            'I numeri sul profilo sono pulsanti.\n\n'
            '· Tocca la quota di un lato per cambiarla.\n'
            '· Tocca il badge arancione di una piega per cambiarne angolo e '
            'verso, o per eliminarla: i due lembi si uniscono e le lunghezze '
            'si sommano.\n'
            '· Tocca un «+» a una delle due estremità per aggiungere un lato.\n\n'
            'Materiale, spessore e cava stanno nelle tre pastiglie sotto il '
            'disegno.',
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

/// Pastiglia compatta: etichetta piccola sopra, valore grande sotto.
class _Pastiglia extends StatelessWidget {
  final String etichetta;
  final String valore;
  final VoidCallback onPremuto;
  final bool allarme;

  const _Pastiglia({
    required this.etichetta,
    required this.valore,
    required this.onPremuto,
    this.allarme = false,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Material(
      color: tema.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPremuto,
        child: Container(
          // Altezza minima, non fissa: dentro c'è del testo, e in modalità
          // officina il testo cresce. Un box di altezza fissa con del testo
          // dentro è un overflow che aspetta solo il primo che ingrandisce i
          // caratteri.
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: allarme
                ? Border.all(color: ColoriQualifix.errore, width: 1.6)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etichetta.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valore,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: allarme ? ColoriQualifix.errore : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
