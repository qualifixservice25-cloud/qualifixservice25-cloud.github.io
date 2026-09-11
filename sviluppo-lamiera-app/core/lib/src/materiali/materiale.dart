/// Un materiale da piegare, con i coefficienti che ne governano il
/// comportamento sotto il punzone.
class Materiale {
  /// Identificatore stabile, usato nel JSON salvato. Non tradurre mai.
  final String id;

  /// Nome mostrato all'operatore.
  final String nome;

  /// Raggruppamento per l'elenco a tendina.
  final String famiglia;

  /// Coefficiente `c` della piega in aria: `Ri = c · V`.
  ///
  /// È il numero più importante della tabella. In piega in aria il raggio
  /// interno non si sceglie: lo produce la cava, e questo coefficiente dice
  /// quanto.
  final double coefficienteRaggio;

  /// Resistenza a trazione Rm in N/mm². Serve al calcolo del tonnellaggio
  /// (Fase 2); è già in tabella per non doverla aggiungere dopo.
  final double resistenzaTrazioneMPa;

  /// Rapporto `Ri/S` minimo sotto il quale il materiale rischia di criccare
  /// sul raggio esterno.
  final double rapportoRaggioSpessoreMinimo;

  /// Moltiplicatore di taratura applicato al fattore K teorico.
  ///
  /// Vale 1.0 finché l'operatore non tara il materiale su un pezzo di prova;
  /// da quel momento contiene la verità della *sua* macchina.
  final double correzioneK;

  const Materiale({
    required this.id,
    required this.nome,
    required this.famiglia,
    required this.coefficienteRaggio,
    required this.resistenzaTrazioneMPa,
    required this.rapportoRaggioSpessoreMinimo,
    this.correzioneK = 1.0,
  });

  bool get eTarato => (correzioneK - 1.0).abs() > 1e-6;

  Materiale copiaCon({
    String? nome,
    double? coefficienteRaggio,
    double? resistenzaTrazioneMPa,
    double? rapportoRaggioSpessoreMinimo,
    double? correzioneK,
  }) {
    return Materiale(
      id: id,
      nome: nome ?? this.nome,
      famiglia: famiglia,
      coefficienteRaggio: coefficienteRaggio ?? this.coefficienteRaggio,
      resistenzaTrazioneMPa:
          resistenzaTrazioneMPa ?? this.resistenzaTrazioneMPa,
      rapportoRaggioSpessoreMinimo:
          rapportoRaggioSpessoreMinimo ?? this.rapportoRaggioSpessoreMinimo,
      correzioneK: correzioneK ?? this.correzioneK,
    );
  }

  Map<String, dynamic> aMappa() => {
        'id': id,
        'nome': nome,
        'famiglia': famiglia,
        'coefficienteRaggio': coefficienteRaggio,
        'resistenzaTrazioneMPa': resistenzaTrazioneMPa,
        'rapportoRaggioSpessoreMinimo': rapportoRaggioSpessoreMinimo,
        'correzioneK': correzioneK,
      };

  static Materiale daMappa(Map<String, dynamic> m) => Materiale(
        id: m['id'] as String,
        nome: m['nome'] as String,
        famiglia: (m['famiglia'] as String?) ?? 'Altro',
        coefficienteRaggio: (m['coefficienteRaggio'] as num).toDouble(),
        resistenzaTrazioneMPa:
            (m['resistenzaTrazioneMPa'] as num?)?.toDouble() ?? 400,
        rapportoRaggioSpessoreMinimo:
            (m['rapportoRaggioSpessoreMinimo'] as num?)?.toDouble() ?? 1.0,
        correzioneK: (m['correzioneK'] as num?)?.toDouble() ?? 1.0,
      );

  @override
  String toString() => 'Materiale($id, c=$coefficienteRaggio)';
}
