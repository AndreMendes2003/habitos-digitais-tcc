/// Resultado de uma sessão de foco (RF02).
///
/// Registro imutável: uma vez finalizada, a sessão não muda mais.
/// Por enquanto vive só em memória — a persistência com Hive entra no RF01.
library;

/// Desfecho de uma sessão de foco.
///
/// A distinção entre os dois valores é o insumo do RF03/RF04:
/// [concluida] soma ENERGIA, [interrompida] subtrai.
enum StatusSessao {
  concluida,
  interrompida;

  String get rotulo => switch (this) {
        StatusSessao.concluida => 'CONCLUÍDA',
        StatusSessao.interrompida => 'INTERROMPIDA',
      };
}

class SessaoFoco {
  const SessaoFoco({
    required this.duracaoAlvo,
    required this.duracaoReal,
    required this.inicioEm,
    required this.status,
  });

  /// Duração escolhida pelo usuário antes de iniciar.
  final Duration duracaoAlvo;

  /// Tempo efetivamente decorrido em primeiro plano.
  ///
  /// Medido por relógio de parede (não por contagem de ticks), porque o
  /// Android estrangula timers quando o app perde o primeiro plano.
  final Duration duracaoReal;

  final DateTime inicioEm;

  final StatusSessao status;

  bool get foiConcluida => status == StatusSessao.concluida;

  /// Fração da duração alvo que foi cumprida (0.0 a 1.0).
  ///
  /// Candidato a fator de cálculo da ENERGIA no RF03/RF04 — uma sessão
  /// interrompida aos 24 de 25 min não é equivalente a uma abandonada aos 30s.
  double get proporcaoCumprida {
    if (duracaoAlvo.inMilliseconds <= 0) return 0;
    final razao = duracaoReal.inMilliseconds / duracaoAlvo.inMilliseconds;
    return razao.clamp(0.0, 1.0);
  }

  @override
  String toString() =>
      'SessaoFoco(alvo: ${duracaoAlvo.inMinutes}min, '
      'real: ${duracaoReal.inSeconds}s, '
      'inicio: $inicioEm, '
      'status: ${status.name})';
}
