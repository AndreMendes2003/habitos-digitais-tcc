import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../dominio/mascote.dart';
import '../tema/cores.dart';
import '../tema/espacamento.dart';
import '../tema/tipografia.dart';
import 'animacoes_mascote.dart';

/// Mascote no topo da tela de foco (RF01).
///
/// A animação é a leitura visual da FSM: o estado NÃO é armazenado em lugar
/// nenhum, sai da energia em [Mascote.estado], e este widget só desenha o que
/// vier. Nenhuma regra mora aqui.
///
/// A composição vem do cache de [AnimacoesMascote], nunca de um
/// `Lottie.asset` direto: um asset lido no meio da troca de estado
/// engasgaria justamente no quadro em que o usuário está olhando.
class WidgetMascote extends StatelessWidget {
  const WidgetMascote({required this.mascote, super.key});

  /// Fade curto: longo o bastante para não ser corte seco, curto o bastante
  /// para a mudança de energia ainda parecer consequência do que acabou de
  /// acontecer.
  static const Duration duracaoTransicao = Duration(milliseconds: 300);

  /// Fração da largura da tela ocupada pela animação.
  static const double _fracaoDaLargura = 0.5;

  /// Limites em pixels lógicos. Sem o teto, a animação domina a tela em
  /// tablet; sem o piso, some num celular estreito.
  static const double _ladoMinimo = 140;
  static const double _ladoMaximo = 260;

  final Mascote mascote;

  Color _cor() => switch (mascote.estado) {
        EstadoMascote.feliz => Cores.feliz,
        EstadoMascote.neutro => Cores.neutro,
        EstadoMascote.cansado => Cores.cansado,
      };

  @override
  Widget build(BuildContext context) {
    final cor = _cor();
    final lado = (MediaQuery.sizeOf(context).width * _fracaoDaLargura)
        .clamp(_ladoMinimo, _ladoMaximo);

    return Column(
      children: [
        SizedBox(
          height: lado,
          width: lado,
          child: AnimatedSwitcher(
            duration: duracaoTransicao,
            // Os dois lados do fade se sobrepõem no mesmo espaço; sem isto o
            // AnimatedSwitcher empilharia as duas animações e a caixa saltaria
            // de tamanho no meio da transição.
            layoutBuilder: (atual, anteriores) => Stack(
              alignment: Alignment.center,
              children: [...anteriores, ?atual],
            ),
            child: _animacao(lado),
          ),
        ),
        const SizedBox(height: Espacamento.xs),
        Text(
          mascote.estado.rotulo,
          // 18 fica entre `corpo` (16) e `titulo` (24). Preservado como está
          // para não mexer no layout nesta passada; a escala será revista na
          // fase visual.
          style: Tipografia.corpo.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cor,
          ),
        ),
        const SizedBox(height: Espacamento.sm),
        LinearProgressIndicator(
          value: mascote.proporcaoEnergia,
          minHeight: 10,
          color: cor,
        ),
        const SizedBox(height: Espacamento.xs),
        Text('Energia: ${mascote.energia}/100'),
      ],
    );
  }

  /// A chave por estado é o que faz o AnimatedSwitcher perceber a troca — sem
  /// ela ele veria o mesmo tipo de widget e trocaria a composição sem fade.
  Widget _animacao(double lado) {
    final composicao = AnimacoesMascote.de(mascote.estado);

    if (composicao == null) {
      // Cache não carregado (teste de widget, ou asset ausente). Ocupa o
      // mesmo espaço para o layout não mudar conforme a animação chega.
      return SizedBox(
        key: ValueKey('sem-animacao-${mascote.estado.name}'),
        height: lado,
        width: lado,
      );
    }

    return Lottie(
      key: ValueKey(mascote.estado),
      composition: composicao,
      height: lado,
      width: lado,
      fit: BoxFit.contain,
      repeat: true,
    );
  }
}
