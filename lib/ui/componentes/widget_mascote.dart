import 'dart:math' as math;

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
  static const double _larguraMinima = 140;
  static const double _larguraMaxima = 260;

  /// Altura da caixa, como fração da largura.
  ///
  /// FIXA, e não derivada de cada animação: as três artes têm proporções
  /// diferentes (altura/largura de 0.51 a 0.70), e uma caixa que
  /// acompanhasse cada uma mudaria de altura no meio do fade, empurrando o
  /// rótulo e a barra de energia a cada troca de estado.
  ///
  /// O valor é o aspecto da arte mais larga das três — a que mais restringe.
  /// Assim nenhuma precisa ser cortada para caber, e a que sobra folga fica
  /// centralizada em vez de flutuar num quadrado.
  static const double _alturaRelativa = 0.62;

  final Mascote mascote;

  Color _cor() => switch (mascote.estado) {
        EstadoMascote.feliz => Cores.feliz,
        EstadoMascote.neutro => Cores.neutro,
        EstadoMascote.cansado => Cores.cansado,
      };

  @override
  Widget build(BuildContext context) {
    final cor = _cor();
    final largura = (MediaQuery.sizeOf(context).width * _fracaoDaLargura)
        .clamp(_larguraMinima, _larguraMaxima);
    final altura = largura * _alturaRelativa;

    return Column(
      children: [
        SizedBox(
          height: altura,
          width: largura,
          child: AnimatedSwitcher(
            duration: duracaoTransicao,
            // Os dois lados do fade se sobrepõem no mesmo espaço; sem isto o
            // AnimatedSwitcher empilharia as duas animações e a caixa saltaria
            // de tamanho no meio da transição.
            layoutBuilder: (atual, anteriores) => Stack(
              alignment: Alignment.center,
              children: [...anteriores, ?atual],
            ),
            child: _animacao(largura, altura),
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
  Widget _animacao(double largura, double altura) {
    final composicao = AnimacoesMascote.de(mascote.estado);

    if (composicao == null) {
      // Cache não carregado (teste de widget, ou asset ausente). Ocupa o
      // mesmo espaço para o layout não mudar conforme a animação chega.
      return SizedBox(
        key: ValueKey('sem-animacao-${mascote.estado.name}'),
        height: altura,
        width: largura,
      );
    }

    final recorte = AnimacoesMascote.conteudoComFolga(mascote.estado);

    // Lado do canvas QUADRADO em que a composição é desenhada, escolhido para
    // que só o recorte preencha a caixa. Contain e não cover: cobrir cortaria
    // orelha, rabo ou os corações que flutuam acima do gato.
    final ladoCanvas = math.min(
      largura / recorte.width,
      altura / recorte.height,
    );

    // Canto superior esquerdo do canvas, de modo que o centro do recorte caia
    // no centro da caixa.
    final deslocamento = Offset(
      (largura - recorte.width * ladoCanvas) / 2 - recorte.left * ladoCanvas,
      (altura - recorte.height * ladoCanvas) / 2 - recorte.top * ladoCanvas,
    );

    return ClipRect(
      key: ValueKey(mascote.estado),
      child: SizedBox(
        width: largura,
        height: altura,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: deslocamento,
            child: Lottie(
              composition: composicao,
              width: ladoCanvas,
              height: ladoCanvas,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }
}
