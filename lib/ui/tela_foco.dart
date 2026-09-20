import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dominio/controlador_sessao.dart';
import '../estado/estado_mascote.dart';
import 'componentes/botao_principal.dart';
import 'formato_duracao.dart';
import 'tema/cores.dart';
import 'tema/espacamento.dart';
import 'tema/tipografia.dart';

/// Aba Foco: a sessão de foco (RF02) e o desfecho da última (RF03/RF04).
///
/// O cronômetro NÃO mora aqui. Quem conta é o ControladorSessao, dentro do
/// [EstadoApp] que vive acima do MaterialApp — por isso sair desta aba e
/// voltar não interrompe nem reinicia nada: esta tela só desenha o que já
/// estava correndo.
class TelaFoco extends StatelessWidget {
  const TelaFoco({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoApp>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Espacamento.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _seletorDuracao(estado),
          const SizedBox(height: Espacamento.xl),
          Center(
            child: Text(
              formatarDuracao(estado.tempoRestante),
              style: Tipografia.cronometro,
            ),
          ),
          const SizedBox(height: Espacamento.xl),
          _botaoPrincipal(estado),
          const SizedBox(height: Espacamento.xl),
          _resultado(estado),
        ],
      ),
    );
  }

  Widget _seletorDuracao(EstadoApp estado) {
    return SegmentedButton<Duration>(
      segments: [
        for (final d in ControladorSessao.duracoesDisponiveis)
          ButtonSegment<Duration>(
            value: d,
            label: Text('${d.inMinutes} min'),
          ),
      ],
      selected: {estado.duracaoAlvo},
      onSelectionChanged: estado.sessaoEmAndamento
          ? null
          : (selecao) => estado.selecionarDuracao(selecao.first),
    );
  }

  Widget _botaoPrincipal(EstadoApp estado) {
    return switch (estado.estadoSessao) {
      EstadoSessao.ocioso => BotaoPrincipal(
          rotulo: 'Iniciar foco',
          onPressed: estado.iniciarSessao,
        ),
      // Sem callback: desabilitado sai do mesmo dado que o comportamento.
      EstadoSessao.emAndamento => const BotaoPrincipal(
          rotulo: 'Em foco — não saia do app',
          onPressed: null,
        ),
      EstadoSessao.finalizada => BotaoPrincipal(
          rotulo: 'Nova sessão',
          onPressed: estado.reiniciarSessao,
        ),
    };
  }

  Widget _resultado(EstadoApp estado) {
    final sessao = estado.ultimaSessao;
    if (sessao == null) {
      return const Text(
        'Nenhuma sessão finalizada nesta execução.',
        textAlign: TextAlign.center,
      );
    }

    return Column(
      children: [
        Text(
          sessao.status.rotulo,
          // Interrompida usa `cansado`, não `alerta`: abandonar uma sessão
          // não é erro do usuário, e a cor de alerta é reservada ao excesso
          // de uso de redes sociais.
          style: Tipografia.titulo.copyWith(
            color: sessao.foiConcluida ? Cores.feliz : Cores.cansado,
          ),
        ),
        const SizedBox(height: Espacamento.sm),
        Text('Alvo: ${sessao.duracaoAlvo.inMinutes} min'),
        Text('Real: ${formatarDuracao(sessao.duracaoReal)}'),
        Text('Início: ${formatoInicio.format(sessao.inicioEm)}'),
      ],
    );
  }
}
