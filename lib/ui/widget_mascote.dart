import 'package:flutter/material.dart';

import '../dominio/mascote.dart';
import 'tema/cores.dart';
import 'tema/espacamento.dart';
import 'tema/tipografia.dart';

/// Mascote no topo da tela de foco (RF01).
///
/// PLACEHOLDER: emoji e barra. A animação (Rive/Lottie) fica para depois do
/// PC2 — trocar só este widget, o domínio não muda.
class WidgetMascote extends StatelessWidget {
  const WidgetMascote({required this.mascote, super.key});

  final Mascote mascote;

  String get _emoji => switch (mascote.estado) {
        EstadoMascote.feliz => '😄',
        EstadoMascote.neutro => '😐',
        EstadoMascote.cansado => '😴',
      };

  /// As cores de estado vêm da paleta, não de `Colors.*`: são a leitura
  /// visual da FSM, então precisam ser as mesmas em qualquer tela que venha
  /// a mostrar o mascote.
  Color _cor(BuildContext context) => switch (mascote.estado) {
        EstadoMascote.feliz => Cores.feliz,
        EstadoMascote.neutro => Cores.neutro,
        EstadoMascote.cansado => Cores.cansado,
      };

  @override
  Widget build(BuildContext context) {
    final cor = _cor(context);

    return Column(
      children: [
        // Emoji não leva família tipográfica: quem o desenha é a fonte de
        // emoji do sistema, e forçar Nunito aqui não mudaria nada.
        Text(_emoji, style: const TextStyle(fontSize: 56)),
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
}
