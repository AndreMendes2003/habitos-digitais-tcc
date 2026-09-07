/// Parâmetros numéricos do RF01/RF03/RF04.
///
/// VALORES PROVISÓRIOS: são a calibragem do serious game, não uma constante
/// física. Este é o único lugar onde eles aparecem — ajuste aqui e o resto do
/// app acompanha.
library;

import 'dart:math' as math;

import 'sessao_foco.dart';

abstract final class RegrasEnergia {
  /// Faixa válida da ENERGIA. Todo valor entra clampado aqui.
  static const int energiaMinima = 0;
  static const int energiaMaxima = 100;

  /// Mascote novo nasce Neutro.
  static const int energiaInicial = 50;

  /// Limiares da FSM. Feliz é `energia >= limiarFeliz`;
  /// Cansado é `energia < limiarCansado`; Neutro é o intervalo entre eles.
  static const int limiarFeliz = 70;
  static const int limiarCansado = 30;

  /// Deltas aplicados ao fim de cada sessão de foco (RF03/RF04).
  ///
  /// Assinados de propósito: aplicar é sempre uma soma, então não existe
  /// ponto no código onde o sinal possa ser invertido por engano.
  static const int deltaSessaoConcluida = 15;
  static const int deltaSessaoInterrompida = -10;

  /// RF04, primeiro ramo: quanto o desfecho de uma sessão vale em ENERGIA.
  static int deltaParaSessao(StatusSessao status) => switch (status) {
        StatusSessao.concluida => deltaSessaoConcluida,
        StatusSessao.interrompida => deltaSessaoInterrompida,
      };

  // --- RF04, segundo ramo: uso de redes sociais -----------------------------
  // PROVISÓRIOS, sujeitos a calibração no piloto. O limiar de 120 min/dia não
  // vem de literatura: é um ponto de partida para observar o comportamento.

  /// Minutos diários de rede social tolerados sem penalidade.
  static const int limiteDiarioRedesSociaisMinutos = 120;

  /// Tamanho do bloco excedente. Só blocos COMPLETOS penalizam.
  static const int blocoExcedenteMinutos = 30;

  /// Custo de cada bloco completo acima do limite.
  static const int deltaPorBlocoExcedido = -5;

  /// Piso da penalidade diária, por pior que seja o dia.
  static const int penalidadeMaximaDiaria = -30;

  /// Penalidade ACUMULADA do dia para um total de [minutos]. Sempre <= 0.
  ///
  /// Acumulada, e não incremental, de propósito: com ela a idempotência vira
  /// uma subtração entre o que a regra manda hoje e o que já foi cobrado —
  /// ver ControladorUso.
  static int penalidadeAcumulada(int minutos) {
    final excedente = minutos - limiteDiarioRedesSociaisMinutos;
    if (excedente <= 0) return 0;

    final blocosCompletos = excedente ~/ blocoExcedenteMinutos;
    final penalidade = blocosCompletos * deltaPorBlocoExcedido;
    return math.max(penalidade, penalidadeMaximaDiaria);
  }
}
