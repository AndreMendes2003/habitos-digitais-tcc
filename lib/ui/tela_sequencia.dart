import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_mascote.dart';
import 'formato_duracao.dart';
import 'tema/cores.dart';
import 'tema/espacamento.dart';

/// Aba Sequência: o histórico persistido de sessões de foco.
///
/// A sequência de dias do RF07 (`estado.sequenciaAtual`, `maiorSequencia`,
/// `ultimos30Dias`) ainda NÃO é exibida aqui: a camada visual do RF07 não
/// faz parte desta reorganização, que só move conteúdo existente de lugar.
class TelaSequencia extends StatelessWidget {
  const TelaSequencia({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoApp>();

    if (estado.historico.isEmpty) {
      // Na tela antiga o histórico simplesmente não aparecia quando vazio.
      // Numa aba própria isso seria uma tela em branco sem explicação.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Espacamento.xl),
          child: Text(
            'Nenhuma sessão registrada ainda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).disabledColor),
          ),
        ),
      );
    }

    /// Já da sessão mais recente para a mais antiga (RepositorioSessoes).
    return ListView.builder(
      padding: const EdgeInsets.all(Espacamento.lg),
      itemCount: estado.historico.length,
      itemBuilder: (context, indice) {
        final s = estado.historico[indice];
        return ListTile(
          dense: true,
          leading: Icon(
            s.foiConcluida ? Icons.check_circle : Icons.cancel,
            color: s.foiConcluida ? Cores.feliz : Cores.cansado,
          ),
          title: Text('${s.duracaoAlvo.inMinutes} min — ${s.status.rotulo}'),
          subtitle: Text('real: ${formatarDuracao(s.duracaoReal)}'),
        );
      },
    );
  }
}
