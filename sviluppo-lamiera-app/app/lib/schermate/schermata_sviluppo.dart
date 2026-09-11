import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import '../comuni/widget_comuni.dart';
import '../disegno/painter_profilo.dart';
import '../disegno/vista_2d.dart';
import '../stato/stato_app.dart';
import '../tema/tema.dart';

/// Il pezzo e la sua lunghezza da tagliare.
class SchermataSviluppo extends StatelessWidget {
  const SchermataSviluppo({super.key});

  @override
  Widget build(BuildContext context) {
    final stato = FornitoreStato.di(context);
    final profilo = stato.profilo;
    final sviluppo = stato.sviluppo;
    final colori = ColoriDisegno.da(Theme.of(context));

    return Column(
      children: [
        AppBar(
          title: const Text('Sviluppo'),
          actions: [
            IconButton(
              tooltip: 'Aggiungi tratto',
              icon: const Icon(Icons.add),
              onPressed: () => stato.aggiornaProfilo(
                profilo.conTrattoAggiunto(lunghezza: 50),
              ),
            ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, vincoli) {
              final affiancato = vincoli.maxWidth >= 900;
              final disegno = _pannelloDisegno(
                context,
                stato,
                sviluppo,
                colori,
                affiancato,
              );
              final modifica = _pannelloModifica(context, stato, sviluppo);

              if (!affiancato) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [disegno, ...modifica],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 32),
                      children: modifica,
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 32),
                      child: disegno,
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

  Widget _pannelloDisegno(
    BuildContext context,
    StatoApp stato,
    RisultatoSviluppo sviluppo,
    ColoriDisegno colori,
    bool affiancato,
  ) {
    final profilo = stato.profilo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SchedaRisultato(
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
              : 'manca un dato: vedi gli avvisi qui sotto',
          icona: Icons.straighten,
          colore: sviluppo.eAttendibile ? null : ColoriQualifix.errore,
        ),
        if (sviluppo.eAttendibile && sviluppo.pieghe.isNotEmpty) ...[
          const TitoloSezione('IL PEZZO FINITO'),
          Card(
            child: SizedBox(
              height: affiancato ? 260 : 200,
              child: CustomPaint(
                painter: PainterProfilo(
                  geometria: CostruttoreGeometria.costruisci(
                    profilo: profilo,
                    trattiPiani: sviluppo.trattiPiani,
                    pieghe: sviluppo.pieghe,
                  ),
                  profilo: profilo,
                  sviluppo: sviluppo,
                  colori: colori,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const TitoloSezione('LA LAMIERA DA TAGLIARE'),
          Card(
            child: SizedBox(
              height: 130,
              child: CustomPaint(
                painter: PainterSviluppo(
                  sviluppo: sviluppo,
                  spessore: profilo.spessore,
                  colori: colori,
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
        ],
        if (sviluppo.avvertimenti.isNotEmpty) ...[
          const TitoloSezione('DA VERIFICARE'),
          BannerAvvertimenti(avvertimenti: sviluppo.avvertimenti),
        ],
        const AvvisoProvino(),
      ],
    );
  }

  List<Widget> _pannelloModifica(
    BuildContext context,
    StatoApp stato,
    RisultatoSviluppo sviluppo,
  ) {
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
        onSelectionChanged: (scelta) => stato.aggiornaProfilo(
          profilo.copiaCon(quotatura: scelta.first),
        ),
      ),
      const TitoloSezione('MISURE DEL PEZZO'),
      for (var i = 0; i < profilo.tratti.length; i++) ...[
        _rigaTratto(context, stato, i, sviluppo),
        if (i < profilo.pieghe.length) _rigaPiega(context, stato, i),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi tratto'),
              onPressed: () => stato.aggiornaProfilo(
                profilo.conTrattoAggiunto(lunghezza: 50),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.remove),
              label: const Text('Togli ultimo'),
              onPressed: profilo.tratti.length <= 2
                  ? null
                  : () => stato.aggiornaProfilo(
                        profilo.senzaTratto(profilo.tratti.length - 1),
                      ),
            ),
          ),
        ],
      ),
      if (sviluppo.eAttendibile) ...[
        const TitoloSezione('DETTAGLIO PER PIEGA'),
        _tabellaPieghe(context, sviluppo),
      ],
    ];
  }

  Widget _rigaTratto(
    BuildContext context,
    StatoApp stato,
    int indice,
    RisultatoSviluppo sviluppo,
  ) {
    final profilo = stato.profilo;
    final tratto = profilo.tratti[indice];
    final piatto = indice < sviluppo.righe.length
        ? sviluppo.righe[indice].quotaPiatta
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: CampoNumerico(
        etichetta: 'Tratto ${tratto.etichetta}',
        valore: tratto.lunghezza,
        aiuto: piatto != null && profilo.quotatura == QuotaturaProfilo.esterna
            ? 'disteso: ${FormatoNumero.mm(piatto, decimali: 2)}'
            : null,
        onCambiato: (v) {
          if (v == null) return;
          final nuovi = [...profilo.tratti];
          nuovi[indice] = tratto.copiaCon(lunghezza: v);
          stato.aggiornaProfilo(profilo.copiaCon(tratti: nuovi));
        },
      ),
    );
  }

  Widget _rigaPiega(BuildContext context, StatoApp stato, int indice) {
    final profilo = stato.profilo;
    final piega = profilo.pieghe[indice];

    void aggiorna(PiegaProfilo nuova) {
      final nuove = [...profilo.pieghe];
      nuove[indice] = nuova;
      stato.aggiornaProfilo(profilo.copiaCon(pieghe: nuove));
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: ColoriQualifix.accento.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: ColoriQualifix.accento,
            child: Text(
              '${indice + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CampoNumerico(
              etichetta: 'Angolo piega ${indice + 1}',
              suffisso: '°',
              valore: piega.angoloFormato,
              onCambiato: (v) {
                if (v != null) aggiorna(piega.copiaCon(angoloFormato: v));
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Verso: ${piega.verso.etichetta}',
            iconSize: 26,
            icon: Icon(
              piega.verso == VersoPiega.su
                  ? Icons.turn_slight_left
                  : Icons.turn_slight_right,
            ),
            onPressed: () => aggiorna(piega.copiaCon(verso: piega.verso.opposto)),
          ),
        ],
      ),
    );
  }

  Widget _tabellaPieghe(BuildContext context, RisultatoSviluppo sviluppo) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 22,
          headingTextStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
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
                DataCell(Text(
                    FormatoNumero.fattore(sviluppo.pieghe[i].fattoreK))),
                DataCell(Text(FormatoNumero.misura(sviluppo.pieghe[i].ba,
                    decimali: 2))),
                DataCell(Text(FormatoNumero.misura(sviluppo.pieghe[i].bd,
                    decimali: 2))),
              ]),
          ],
        ),
      ),
    );
  }
}
