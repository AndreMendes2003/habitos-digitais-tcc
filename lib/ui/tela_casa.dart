import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dominio/regras_energia.dart';
import '../estado/estado_mascote.dart';
import 'componentes/widget_mascote.dart';
import 'tema/cores.dart';
import 'tema/espacamento.dart';
import 'tema/tipografia.dart';

/// Aba Casa: o estado do mascote (RF01) e a leitura de uso do dia (RF04).
///
/// Só lê o [EstadoApp] do provider — nenhum estado próprio, nenhum
/// controlador. É a mesma instância que as outras abas enxergam.
class TelaCasa extends StatelessWidget {
  const TelaCasa({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoApp>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Espacamento.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WidgetMascote(mascote: estado.mascote),
          const SizedBox(height: Espacamento.sm),
          _statusRedesSociais(context, estado),
        ],
      ),
    );
  }

  /// RF04, item 7: linha única de status. Sem tela nova.
  Widget _statusRedesSociais(BuildContext context, EstadoApp estado) {
    if (estado.medicaoUsoPendente) {
      // Ainda não houve medição. Mostrar "0 min" aqui seria afirmar um dado
      // que o app não tem — e 0 é justamente o valor de um dia perfeito.
      return Text(
        'Redes sociais hoje: medindo...',
        textAlign: TextAlign.center,
        style: Tipografia.corpo.copyWith(
          color: Theme.of(context).disabledColor,
        ),
      );
    }

    if (!estado.permissaoUsoConcedida) {
      // Item 6: sem permissão não se penaliza, mas o usuário precisa saber.
      // `neutro`, e não `alerta`: falta de permissão é uma pendência de
      // configuração, não o excesso de uso que a cor de alerta sinaliza.
      return Text(
        'Redes sociais hoje: permissão não concedida',
        textAlign: TextAlign.center,
        style: Tipografia.corpo.copyWith(color: Cores.neutro),
      );
    }

    final minutos = estado.minutosRedesSociaisHoje;
    final limite = RegrasEnergia.limiteDiarioRedesSociaisMinutos;

    return Text(
      'Redes sociais hoje: $minutos min / $limite min',
      textAlign: TextAlign.center,
      style: Tipografia.corpo.copyWith(
        // Único uso legítimo de `alerta`: passou do limite diário.
        color: minutos > limite ? Cores.alerta : null,
        fontWeight: minutos > limite ? FontWeight.w700 : null,
      ),
    );
  }
}
