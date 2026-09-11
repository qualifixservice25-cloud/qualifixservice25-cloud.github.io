import 'package:flutter/material.dart';

import 'dati/archivio.dart';
import 'schermate/schermata_impostazioni.dart';
import 'schermate/schermata_piega.dart';
import 'schermate/schermata_sequenza.dart';
import 'schermate/schermata_sviluppo.dart';
import 'schermate/schermata_utensili.dart';
import 'stato/stato_app.dart';
import 'tema/tema.dart';

void main() {
  runApp(AppSviluppoLamiera(archivio: ArchivioPreferenze()));
}

class AppSviluppoLamiera extends StatefulWidget {
  final Archivio archivio;

  const AppSviluppoLamiera({super.key, required this.archivio});

  @override
  State<AppSviluppoLamiera> createState() => _AppSviluppoLamieraState();
}

class _AppSviluppoLamieraState extends State<AppSviluppoLamiera> {
  late final StatoApp _stato = StatoApp(widget.archivio);

  @override
  void initState() {
    super.initState();
    _stato.carica();
  }

  @override
  void dispose() {
    _stato.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FornitoreStato(
      stato: _stato,
      child: ListenableBuilder(
        listenable: _stato,
        builder: (context, _) {
          return MaterialApp(
            title: 'Sviluppo Lamiera',
            debugShowCheckedModeBanner: false,
            theme: _stato.impostazioni.modalitaOfficina
                ? TemaApp.officina()
                : TemaApp.chiaro(),
            builder: (context, figlio) {
              // Il testo non deve mai rimpicciolirsi sotto la misura scelta:
              // questa app si legge a distanza di braccio. In modalità
              // officina la soglia sale ancora.
              final minimo = _stato.impostazioni.modalitaOfficina
                  ? TemaApp.ingrandimentoOfficina
                  : 1.0;
              return MediaQuery.withClampedTextScaling(
                minScaleFactor: minimo,
                maxScaleFactor: minimo * 1.6,
                child: figlio!,
              );
            },
            home: const PaginaPrincipale(),
          );
        },
      ),
    );
  }
}

class PaginaPrincipale extends StatefulWidget {
  const PaginaPrincipale({super.key});

  @override
  State<PaginaPrincipale> createState() => _PaginaPrincipaleState();
}

class _PaginaPrincipaleState extends State<PaginaPrincipale> {
  int _scheda = 0;

  static const _schede = <({String nome, IconData icona, IconData iconaPiena})>[
    (nome: 'Piega', icona: Icons.architecture_outlined, iconaPiena: Icons.architecture),
    (nome: 'Sviluppo', icona: Icons.straighten_outlined, iconaPiena: Icons.straighten),
    (nome: 'Sequenza', icona: Icons.reorder_outlined, iconaPiena: Icons.reorder),
    (nome: 'Utensili', icona: Icons.handyman_outlined, iconaPiena: Icons.handyman),
    (nome: 'Impostazioni', icona: Icons.tune_outlined, iconaPiena: Icons.tune),
  ];

  @override
  Widget build(BuildContext context) {
    final stato = FornitoreStato.di(context);

    if (!stato.caricato) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: switch (_scheda) {
          0 => const SchermataPiega(),
          1 => const SchermataSviluppo(),
          2 => const SchermataSequenza(),
          3 => const SchermataUtensili(),
          _ => const SchermataImpostazioni(),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _scheda,
        onDestinationSelected: (i) => setState(() => _scheda = i),
        destinations: [
          for (var i = 0; i < _schede.length; i++)
            NavigationDestination(
              icon: Icon(_schede[i].icona),
              selectedIcon: Icon(_schede[i].iconaPiena),
              label: _schede[i].nome,
            ),
        ],
      ),
    );
  }
}
