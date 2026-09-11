import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sviluppo_lamiera_core/sviluppo_lamiera_core.dart';

import '../tema/tema.dart';

/// Campo numerico che accetta sia la virgola sia il punto.
///
/// Chi lavora scrive «2,5»: pretendere il punto decimale è un modo sicuro per
/// farsi inserire dati sbagliati.
class CampoNumerico extends StatefulWidget {
  final String etichetta;
  final String? suffisso;
  final double? valore;
  final ValueChanged<double?> onCambiato;
  final String? aiuto;
  final bool abilitato;

  const CampoNumerico({
    super.key,
    required this.etichetta,
    required this.valore,
    required this.onCambiato,
    this.suffisso = 'mm',
    this.aiuto,
    this.abilitato = true,
  });

  @override
  State<CampoNumerico> createState() => _CampoNumericoState();
}

class _CampoNumericoState extends State<CampoNumerico> {
  late final TextEditingController _controllo = TextEditingController(
    text: widget.valore == null
        ? ''
        : FormatoNumero.misura(widget.valore!, decimali: 2)
            .replaceAll(RegExp(r',?0+$'), ''),
  );

  @override
  void didUpdateWidget(CampoNumerico vecchio) {
    super.didUpdateWidget(vecchio);
    if (widget.valore != vecchio.valore) {
      final letto = FormatoNumero.leggi(_controllo.text);
      if (letto == null || (letto - (widget.valore ?? 0)).abs() > 1e-6) {
        _controllo.text = widget.valore == null
            ? ''
            : FormatoNumero.misura(widget.valore!, decimali: 2)
                .replaceAll(RegExp(r',?0+$'), '');
      }
    }
  }

  @override
  void dispose() {
    _controllo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controllo,
      enabled: widget.abilitato,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: widget.etichetta,
        suffixText: widget.suffisso,
        helperText: widget.aiuto,
        helperMaxLines: 3,
      ),
      onChanged: (testo) => widget.onCambiato(FormatoNumero.leggi(testo)),
    );
  }
}

/// La scheda del risultato principale: numero grande, nome sopra, contesto
/// sotto.
class SchedaRisultato extends StatelessWidget {
  final String titolo;
  final String valore;
  final String? sottotitolo;
  final Color? colore;
  final IconData? icona;

  const SchedaRisultato({
    super.key,
    required this.titolo,
    required this.valore,
    this.sottotitolo,
    this.colore,
    this.icona,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tinta = colore ?? tema.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icona != null) ...[
                  Icon(icona, size: 20, color: tinta),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    titolo.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                valore,
                style: TextStyle(
                  fontSize: TemaApp.corpoRisultato,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: tinta,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (sottotitolo != null) ...[
              const SizedBox(height: 6),
              Text(
                sottotitolo!,
                style: TextStyle(
                  fontSize: 14,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una riga della catena di derivazione.
///
/// È il pezzo di interfaccia che rende verificabile il risultato: senza la
/// derivazione, 196,0 e 194,0 sono ugualmente credibili e nessuno può
/// accorgersi dell'errore prima di aver tagliato.
class RigaCatena extends StatelessWidget {
  final PassoCatena passo;

  const RigaCatena({super.key, required this.passo});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final coloreOrigine = switch (passo.origine) {
      OrigineValore.impostoDallUtente => ColoriQualifix.accento,
      OrigineValore.tarato => ColoriQualifix.successo,
      _ => tema.colorScheme.onSurfaceVariant,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passo.etichetta,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  passo.formula,
                  style: TextStyle(
                    fontSize: 13,
                    color: tema.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                passo.valore,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (passo.origine != OrigineValore.din6935)
                Text(
                  passo.origine.etichetta,
                  style: TextStyle(fontSize: 11.5, color: coloreOrigine),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Elenco degli avvertimenti, ordinati per gravità.
class BannerAvvertimenti extends StatelessWidget {
  final List<Avvertimento> avvertimenti;
  final bool compatto;

  const BannerAvvertimenti({
    super.key,
    required this.avvertimenti,
    this.compatto = false,
  });

  @override
  Widget build(BuildContext context) {
    if (avvertimenti.isEmpty) return const SizedBox.shrink();

    final visibili = compatto
        ? avvertimenti.ordinatiPerGravita.take(3).toList()
        : avvertimenti.ordinatiPerGravita;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in visibili) _riga(context, a),
        if (compatto && avvertimenti.length > visibili.length)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'e altri ${avvertimenti.length - visibili.length} avvisi',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _riga(BuildContext context, Avvertimento a) {
    final (colore, icona) = switch (a.gravita) {
      GravitaAvvertimento.errore => (ColoriQualifix.errore, Icons.error_outline),
      GravitaAvvertimento.attenzione => (
          ColoriQualifix.attenzione,
          Icons.warning_amber_outlined
        ),
      GravitaAvvertimento.informazione => (
          ColoriQualifix.successo,
          Icons.info_outline
        ),
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: colore, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icona, size: 19, color: colore),
          const SizedBox(width: 10),
          Expanded(
            child: Text(a.messaggio, style: const TextStyle(fontSize: 14.5)),
          ),
        ],
      ),
    );
  }
}

/// Intestazione di sezione dentro una schermata.
class TitoloSezione extends StatelessWidget {
  final String testo;
  final Widget? azione;

  const TitoloSezione(this.testo, {super.key, this.azione});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              testo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (azione != null) azione!,
        ],
      ),
    );
  }
}

/// La frase più utile dell'app, e probabilmente la più noiosa.
class AvvisoProvino extends StatelessWidget {
  const AvvisoProvino({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColoriQualifix.accento.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined,
              size: 19, color: ColoriQualifix.accento),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Verifica sempre su un ritaglio prima di tagliare la serie.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
