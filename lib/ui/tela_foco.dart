import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../diagnostico/tela_diagnostico_uso.dart';
import '../dominio/controlador_sessao.dart';

/// Padrão todo numérico: não depende de dados de locale, então dispensa
/// `initializeDateFormatting()`.
final DateFormat _formatoInicio = DateFormat('dd/MM/yyyy HH:mm');

/// Tela única do RF02. Sem polimento: o objetivo é evidenciar o comportamento.
class TelaFoco extends StatefulWidget {
  const TelaFoco({super.key});

  @override
  State<TelaFoco> createState() => _TelaFocoState();
}

class _TelaFocoState extends State<TelaFoco> with WidgetsBindingObserver {
  final ControladorSessao _controlador = ControladorSessao();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // RF01/RF03/RF04: quando o mascote existir, é aqui que a ENERGIA muda.
    // Por ora só registra no console para servir de evidência no device.
    _controlador.aoFinalizarSessao = (sessao) {
      debugPrint('[RF02] $sessao');
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlador.dispose();
    super.dispose();
  }

  /// RNF01: única ponte entre o ciclo de vida do Android e o domínio.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO(remover antes da entrega): log de diagnóstico do RNF01.
    // Serve para levantar, no Samsung, quais estados o Android emite em cada
    // cenário (barra de notificação, chamada, Home, switcher, tela apagando).
    // A ação é deduzida comparando o antes/depois, e não reimplementando a
    // regra de `paused` aqui — o critério mora no ControladorSessao.
    final estavaAtiva = _controlador.emAndamento;

    _controlador.aoMudarCicloDeVida(state);

    final acao = estavaAtiva && !_controlador.emAndamento
        ? 'interrompido'
        : 'ignorado';
    debugPrint(
      '[LIFECYCLE] estado recebido: ${state.name} '
      '| sessão ativa: ${estavaAtiva ? 'sim' : 'não'} '
      '| ação: $acao',
    );
  }

  String _formatar(Duration d) {
    final minutos = d.inMinutes.toString().padLeft(2, '0');
    final segundos = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessão de foco'),
        actions: [
          IconButton(
            tooltip: 'Diagnóstico usage_stats',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TelaDiagnosticoUso(),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controlador,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _seletorDuracao(),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    _formatar(_controlador.tempoRestante),
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
                const SizedBox(height: 24),
                _botaoPrincipal(),
                const SizedBox(height: 24),
                _resultado(),
                const Divider(height: 32),
                Expanded(child: _historico()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _seletorDuracao() {
    return SegmentedButton<Duration>(
      segments: [
        for (final d in ControladorSessao.duracoesDisponiveis)
          ButtonSegment<Duration>(
            value: d,
            label: Text('${d.inMinutes} min'),
          ),
      ],
      selected: {_controlador.duracaoAlvo},
      onSelectionChanged: _controlador.emAndamento
          ? null
          : (selecao) => _controlador.selecionarDuracao(selecao.first),
    );
  }

  Widget _botaoPrincipal() {
    return switch (_controlador.estado) {
      EstadoSessao.ocioso => FilledButton(
          onPressed: _controlador.iniciar,
          child: const Text('Iniciar foco'),
        ),
      EstadoSessao.emAndamento => const FilledButton(
          onPressed: null,
          child: Text('Em foco — não saia do app'),
        ),
      EstadoSessao.finalizada => FilledButton(
          onPressed: _controlador.reiniciar,
          child: const Text('Nova sessão'),
        ),
    };
  }

  Widget _resultado() {
    final sessao = _controlador.ultimaSessao;
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
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: sessao.foiConcluida ? Colors.green : Colors.redAccent,
          ),
        ),
        const SizedBox(height: 8),
        Text('Alvo: ${sessao.duracaoAlvo.inMinutes} min'),
        Text('Real: ${_formatar(sessao.duracaoReal)}'),
        Text('Início: ${_formatoInicio.format(sessao.inicioEm)}'),
      ],
    );
  }

  Widget _historico() {
    final historico = _controlador.historico.reversed.toList();
    if (historico.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      itemCount: historico.length,
      itemBuilder: (context, index) {
        final s = historico[index];
        return ListTile(
          dense: true,
          leading: Icon(
            s.foiConcluida ? Icons.check_circle : Icons.cancel,
            color: s.foiConcluida ? Colors.green : Colors.redAccent,
          ),
          title: Text('${s.duracaoAlvo.inMinutes} min — ${s.status.rotulo}'),
          subtitle: Text('real: ${_formatar(s.duracaoReal)}'),
        );
      },
    );
  }
}
