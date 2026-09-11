/// Motore di calcolo per la piegatura della lamiera.
///
/// Dart puro: questo pacchetto non dipende da Flutter, così i test girano su
/// qualsiasi macchina con il solo SDK Dart, senza SDK Android e senza
/// emulatore. È la stessa proprietà del modulo `core` del CAD Viewer, qui
/// garantita dal `pubspec.yaml` invece che da una convenzione.
library;

export 'src/archivio/impostazioni.dart';
export 'src/archivio/inventario_json.dart';
export 'src/diagnostica/avvertimento.dart';
export 'src/formato/formato_numero.dart';
export 'src/geometria/intersezione.dart';
export 'src/geometria/poligono.dart';
export 'src/geometria/vec2.dart';
export 'src/materiali/materiale.dart';
export 'src/materiali/tabella_materiali.dart';
export 'src/piega/calcolo_piega.dart';
export 'src/piega/calibrazione_k.dart';
export 'src/piega/fattore_k.dart';
export 'src/profilo/geometria_profilo.dart';
export 'src/profilo/profilo_lamiera.dart';
export 'src/sequenza/collisioni.dart';
export 'src/sequenza/lato_minimo.dart';
export 'src/sequenza/motore_sequenza.dart';
export 'src/sequenza/posizionatore.dart';
export 'src/sviluppo/calcolo_sviluppo.dart';
export 'src/utensili/catalogo_standard.dart';
export 'src/utensili/sagoma_utensile.dart';
export 'src/utensili/selezione_matrice.dart';
export 'src/utensili/utensili.dart';
