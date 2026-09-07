import 'package:flutter/material.dart';

import '../dominio/mascote.dart';

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

  Color _cor(BuildContext context) => switch (mascote.estado) {
        EstadoMascote.feliz => Colors.green,
        EstadoMascote.neutro => Colors.amber.shade700,
        EstadoMascote.cansado => Colors.redAccent,
      };

  @override
  Widget build(BuildContext context) {
    final cor = _cor(context);

    return Column(
      children: [
        Text(_emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 4),
        Text(
          mascote.estado.rotulo,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: mascote.proporcaoEnergia,
          minHeight: 10,
          color: cor,
        ),
        const SizedBox(height: 4),
        Text('Energia: ${mascote.energia}/100'),
      ],
    );
  }
}
