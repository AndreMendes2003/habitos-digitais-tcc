/// Estado da avaliação de uso de um dia (RF04).
///
/// É o registro que torna a penalidade idempotente: guarda quantos minutos do
/// dia JÁ FORAM contabilizados, para que reabrir o app não cobre de novo.
library;

class AvaliacaoUsoDiaria {
  const AvaliacaoUsoDiaria({
    required this.dia,
    required this.minutosContabilizados,
  });

  /// Primeiro registro do dia: nada cobrado ainda.
  factory AvaliacaoUsoDiaria.zerada(DateTime dia) {
    return AvaliacaoUsoDiaria(dia: apenasData(dia), minutosContabilizados: 0);
  }

  /// Data sem hora. Comparar DateTime cheio nunca daria igual.
  static DateTime apenasData(DateTime momento) {
    return DateTime(momento.year, momento.month, momento.day);
  }

  final DateTime dia;

  /// Total de minutos do dia sobre o qual a penalidade já foi aplicada.
  final int minutosContabilizados;

  bool ehDoMesmoDia(DateTime momento) => dia == apenasData(momento);

  AvaliacaoUsoDiaria comMinutos(int minutos) {
    return AvaliacaoUsoDiaria(dia: dia, minutosContabilizados: minutos);
  }

  Map<String, dynamic> paraMapa() => {
        'dia': dia.toIso8601String(),
        'minutosContabilizados': minutosContabilizados,
      };

  /// Aceita `Map` cru porque o Hive devolve `Map<dynamic, dynamic>`.
  factory AvaliacaoUsoDiaria.doMapa(Map<dynamic, dynamic> mapa) {
    return AvaliacaoUsoDiaria(
      dia: apenasData(DateTime.parse(mapa['dia'] as String)),
      minutosContabilizados: mapa['minutosContabilizados'] as int,
    );
  }

  @override
  String toString() => 'AvaliacaoUsoDiaria(dia: ${dia.toIso8601String()}, '
      'minutosContabilizados: $minutosContabilizados)';
}
