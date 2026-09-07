/// Mascote virtual (RF01): ENERGIA 0–100 e a FSM derivada dela.
///
/// Regra de negócio pura — sem widget, sem Hive, sem Flame. A animação
/// (Rive/Lottie) fica para depois do PC2 e não muda nada aqui.
library;

import 'regras_energia.dart';
import 'sessao_foco.dart';

/// Estados do mascote. NÃO são armazenados: saem da energia via [Mascote.estado].
enum EstadoMascote {
  feliz,
  neutro,
  cansado;

  String get rotulo => switch (this) {
        EstadoMascote.feliz => 'Feliz',
        EstadoMascote.neutro => 'Neutro',
        EstadoMascote.cansado => 'Cansado',
      };
}

class Mascote {
  /// Clampa na construção, e não só ao aplicar uma sessão.
  ///
  /// Assim um valor fora de faixa vindo do Hive (registro antigo, energia
  /// gravada antes de um ajuste em [RegrasEnergia], dado corrompido) é
  /// normalizado na entrada, em vez de vazar para a barra de energia.
  factory Mascote({int energia = RegrasEnergia.energiaInicial}) {
    return Mascote._(
      energia.clamp(RegrasEnergia.energiaMinima, RegrasEnergia.energiaMaxima),
    );
  }

  const Mascote._(this.energia);

  final int energia;

  /// Estado DERIVADO da energia — nunca persistido separadamente.
  EstadoMascote get estado {
    if (energia >= RegrasEnergia.limiarFeliz) return EstadoMascote.feliz;
    if (energia < RegrasEnergia.limiarCansado) return EstadoMascote.cansado;
    return EstadoMascote.neutro;
  }

  /// Fração de 0.0 a 1.0, pronta para a barra de energia da UI.
  double get proporcaoEnergia => energia / RegrasEnergia.energiaMaxima;

  /// RF03/RF04: aplica o resultado de uma sessão de foco.
  ///
  /// Recebe a [SessaoFoco] inteira, e não só o status, porque a penalidade
  /// proporcional (via [SessaoFoco.proporcaoCumprida]) é um ajuste previsto —
  /// hoje só o desfecho importa.
  Mascote aplicar(SessaoFoco sessao) {
    final delta = switch (sessao.status) {
      StatusSessao.concluida => RegrasEnergia.deltaSessaoConcluida,
      StatusSessao.interrompida => RegrasEnergia.deltaSessaoInterrompida,
    };
    return Mascote(energia: energia + delta);
  }

  @override
  String toString() => 'Mascote(energia: $energia, estado: ${estado.name})';
}
