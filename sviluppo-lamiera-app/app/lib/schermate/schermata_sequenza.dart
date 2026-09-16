import 'package:flutter/material.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import '../comuni/widget_comuni.dart';
import '../disegno/painter_passo.dart';
import '../disegno/vista_2d.dart';
import '../stato/stato_app.dart';
import '../tema/tema.dart';

/// L'ordine delle pieghe, con la verifica di quello che sbatte.
class SchermataSequenza extends StatefulWidget {
  const SchermataSequenza({super.key});

  @override
  State<SchermataSequenza> createState() => _SchermataSequenzaState();
}

class _SchermataSequenzaState extends State<SchermataSequenza> {
  int _sequenzaScelta = 0;
  int _passoMostrato = 0;

  @override
  Widget build(BuildContext context) {
    final stato = FornitoreStato.di(context);
    final risultato = stato.sequenza;

    return Column(
      children: [
        AppBar(
          title: const Text('Sequenza'),
          actions: [
            IconButton(
              tooltip: 'Cosa non viene controllato',
              icon: const Icon(Icons.privacy_tip_outlined),
              onPressed: () => _mostraLimiti(context),
            ),
          ],
        ),
        Expanded(
          child: risultato.sequenze.isEmpty
              ? _vuoto(context, risultato)
              : _contenuto(context, stato, risultato),
        ),
      ],
    );
  }

  Widget _vuoto(BuildContext context, RisultatoSequenza risultato) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Icon(Icons.reorder, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        Text(
          'Nessuna sequenza da proporre',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        BannerAvvertimenti(avvertimenti: risultato.avvertimenti),
      ],
    );
  }

  Widget _contenuto(
    BuildContext context,
    StatoApp stato,
    RisultatoSequenza risultato,
  ) {
    final indice = _sequenzaScelta.clamp(0, risultato.sequenze.length - 1);
    final sequenza = risultato.sequenze[indice];
    final passo = sequenza.passi[_passoMostrato.clamp(0, sequenza.passi.length - 1)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SchedaRisultato(
          titolo: 'Ordine consigliato',
          valore: sequenza.ordine.join(' » '),
          sottotitolo: sequenza.fattibile
              ? '${sequenza.cambiUtensile} cambi utensile · '
                  '${sequenza.ribaltamenti} ribaltamenti'
              : 'questa sequenza incontra un problema: vedi i passi',
          icona: Icons.reorder,
          colore: sequenza.fattibile ? ColoriQualifix.successo : ColoriQualifix.errore,
        ),
        if (risultato.sequenze.length > 1) ...[
          const TitoloSezione('ALTRE PROPOSTE'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < risultato.sequenze.length; i++)
                ChoiceChip(
                  avatar: Icon(
                    risultato.sequenze[i].fattibile
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 18,
                    color: risultato.sequenze[i].fattibile
                        ? ColoriQualifix.successo
                        : ColoriQualifix.errore,
                  ),
                  label: Text(risultato.sequenze[i].ordine.join('-')),
                  selected: i == indice,
                  onSelected: (_) => setState(() {
                    _sequenzaScelta = i;
                    _passoMostrato = 0;
                  }),
                ),
            ],
          ),
        ],
        const TitoloSezione('PASSO PER PASSO'),
        _navigazionePassi(sequenza),
        const SizedBox(height: 10),
        _disegnoPasso(context, stato, passo),
        const SizedBox(height: 10),
        _dettagliPasso(context, stato, passo),
        if (risultato.avvertimenti.isNotEmpty) ...[
          const TitoloSezione('DA VERIFICARE'),
          BannerAvvertimenti(avvertimenti: risultato.avvertimenti),
        ],
        const TitoloSezione('LIMITI DEL CONTROLLO'),
        _limiti(context),
      ],
    );
  }

  Widget _navigazionePassi(SequenzaCandidata sequenza) {
    final corrente = _passoMostrato.clamp(0, sequenza.passi.length - 1);
    return Row(
      children: [
        IconButton.filledTonal(
          iconSize: 28,
          onPressed: corrente == 0
              ? null
              : () => setState(() => _passoMostrato = corrente - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Passo ${corrente + 1} di ${sequenza.passi.length} · '
              'piega ${sequenza.passi[corrente].indicePiega + 1}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          iconSize: 28,
          onPressed: corrente >= sequenza.passi.length - 1
              ? null
              : () => setState(() => _passoMostrato = corrente + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _disegnoPasso(BuildContext context, StatoApp stato, PassoSequenza passo) {
    final sviluppo = stato.sviluppo;
    final matrice = stato.inventario.matricePerId(passo.idMatrice);
    final punzone = stato.inventario.punzonePerId(passo.idPunzone);
    if (matrice == null || punzone == null || !sviluppo.eAttendibile) {
      return const SizedBox.shrink();
    }

    final angolo = stato.profilo.pieghe[passo.indicePiega].angoloFormato;
    final pezzo = PosizionatorePezzo.posa(
      profilo: stato.profilo,
      trattiPiani: sviluppo.trattiPiani,
      pieghe: sviluppo.pieghe,
      matrice: matrice,
      indicePiega: passo.indicePiega,
      giaPiegate: passo.giaPiegate,
      angoloIncluso: angolo,
      ribaltato: passo.ribaltato,
    );

    return Card(
      child: SizedBox(
        height: 280,
        child: CustomPaint(
          painter: PainterPassoSequenza(
            pezzo: pezzo,
            sagomaMatrice: matrice.sagoma,
            sagomaPunzone: RilevatoreCollisioni.sagomaPunzonePosizionata(
              punzone: punzone,
              matrice: matrice,
              angoloIncluso: angolo,
              raggioInterno: sviluppo.pieghe[passo.indicePiega].raggioInterno,
              spessore: stato.profilo.spessore,
            ),
            puntoCritico: passo.collisione.puntoCritico,
            colori: ColoriDisegno.da(Theme.of(context)),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _dettagliPasso(
      BuildContext context, StatoApp stato, PassoSequenza passo) {
    final matrice = stato.inventario.matricePerId(passo.idMatrice);
    final punzone = stato.inventario.punzonePerId(passo.idPunzone);
    final lato = passo.latoPeggiore;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _voce('Coltello', punzone?.nome ?? '—',
                allarme: punzone?.eColloDoca ?? false,
                nota: (punzone?.eColloDoca ?? false)
                    ? "serve il collo d'oca"
                    : null),
            const Divider(height: 1),
            _voce('Cava', matrice?.nome ?? '—'),
            const Divider(height: 1),
            _voce(
              'Lembo più corto',
              FormatoNumero.mm(lato.latoRichiesto),
              allarme: !lato.ammissibile,
              nota: lato.ammissibile
                  ? 'minimo ${FormatoNumero.mm(lato.latoMinimo)}'
                  : 'sotto il minimo di ${FormatoNumero.mm(lato.latoMinimo)}',
            ),
            const Divider(height: 1),
            _voce(
              'Gioco dal coltello',
              passo.collisione.giocoPunzone.isFinite
                  ? FormatoNumero.mm(passo.collisione.giocoPunzone, decimali: 1)
                  : 'ampio',
              allarme: passo.collisione.collide,
              nota: passo.collisione.collide
                  ? 'tocca ${passo.collisione.tipo?.etichetta} a '
                      '${FormatoNumero.gradi(passo.collisione.angoloCritico, decimali: 0)}'
                  : null,
            ),
            const Divider(height: 1),
            _voce('Discesa nella cava',
                FormatoNumero.mm(passo.penetrazione, decimali: 1)),
            if (passo.ribaltato) ...[
              const Divider(height: 1),
              _voce('Pezzo', 'da girare', allarme: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _voce(String titolo, String valore,
      {bool allarme = false, String? nota}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(titolo, style: const TextStyle(fontSize: 15)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valore,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: allarme ? ColoriQualifix.errore : null,
                ),
              ),
              if (nota != null)
                Text(
                  nota,
                  style: TextStyle(
                    fontSize: 12,
                    color: allarme ? ColoriQualifix.errore : Colors.grey,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _limiti(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Queste sono proposte, non verifiche. Il controllo guarda la '
              'sezione del pezzo e non vede:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            for (final limite in RilevatoreCollisioni.limitiNoti)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('· ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        limite,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _mostraLimiti(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cosa non viene controllato'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final limite in RilevatoreCollisioni.limitiNoti)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('· $limite',
                      style: const TextStyle(fontSize: 14.5, height: 1.4)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }
}
