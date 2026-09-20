import 'package:flutter/material.dart';

import '../diagnostico/tela_diagnostico_uso.dart';

/// Atalho para a tela de diagnóstico do usage_stats, no AppBar.
///
/// Extraído para um widget próprio quando a TelaFoco virou três abas: o
/// AppBar passou a ser da casca, e o atalho precisa continuar alcançável de
/// qualquer aba.
class AtalhoDiagnostico extends StatelessWidget {
  const AtalhoDiagnostico({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Diagnóstico usage_stats',
      icon: const Icon(Icons.bar_chart),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const TelaDiagnosticoUso(),
        ),
      ),
    );
  }
}
