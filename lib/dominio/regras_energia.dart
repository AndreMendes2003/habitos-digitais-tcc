/// Parâmetros numéricos do RF01/RF03/RF04.
///
/// VALORES PROVISÓRIOS: são a calibragem do serious game, não uma constante
/// física. Este é o único lugar onde eles aparecem — ajuste aqui e o resto do
/// app acompanha.
library;

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
}
