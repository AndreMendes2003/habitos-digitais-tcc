import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../dados/repositorio_mascote.dart';
import '../dados/repositorio_sessoes.dart';
import '../dados/repositorio_uso.dart';
import '../diagnostico/tela_diagnostico_uso.dart';
import '../dominio/controlador_mascote.dart';
import '../dominio/controlador_sessao.dart';
import '../dominio/controlador_uso.dart';
import '../dominio/regras_energia.dart';
import '../dominio/sessao_foco.dart';
import '../uso/medicao_uso.dart';
import 'widget_mascote.dart';

/// Padrão todo numérico: não depende de dados de locale, então dispensa
/// `initializeDateFormatting()`.
final DateFormat _formatoInicio = DateFormat('dd/MM/yyyy HH:mm');

/// Tela única do RF02 + RF01. Sem polimento: o objetivo é evidenciar o
/// comportamento.
class TelaFoco extends StatefulWidget {
  const TelaFoco({
    required this.repositorioMascote,
    required this.repositorioSessoes,
    required this.repositorioUso,
    required this.medirUso,
    super.key,
  });

  final RepositorioMascote repositorioMascote;
  final RepositorioSessoes repositorioSessoes;
  final RepositorioUso repositorioUso;

  /// Injetada para que o widget test não precise do plugin usage_stats.
  /// Em `main()` aponta para `ServicoUso.medirHoje`.
  final Future<MedicaoUso> Function() medirUso;

  @override
  State<TelaFoco> createState() => _TelaFocoState();
}

class _TelaFocoState extends State<TelaFoco> with WidgetsBindingObserver {
  final ControladorSessao _controlador = ControladorSessao();
  late final ControladorMascote _controladorMascote;
  late final ControladorUso _controladorUso;

  /// Cache do histórico persistido, relido a cada sessão finalizada.
  List<SessaoFoco> _historicoSalvo = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controladorMascote = ControladorMascote(
      inicial: widget.repositorioMascote.carregar(),
      aoPersistir: widget.repositorioMascote.salvar,
    );
    _controladorUso = ControladorUso(
      medir: widget.medirUso,
      avaliacaoInicial: widget.repositorioUso.carregar(),
      aoPersistir: widget.repositorioUso.salvar,
    );
    _historicoSalvo = widget.repositorioSessoes.todas();

    // RF03/RF04: é aqui que o resultado da sessão vira ENERGIA e vai para o
    // disco. O debugPrint continua servindo de evidência no device.
    _controlador.aoFinalizarSessao = (sessao) async {
      debugPrint('[RF02] $sessao');
      await _controladorMascote.registrarSessao(sessao);
      await widget.repositorioSessoes.adicionar(sessao);
      if (mounted) {
        setState(() {
          _historicoSalvo = widget.repositorioSessoes.todas();
        });
      }
      // RF04, gatilho 2: fim de sessão.
      await _avaliarUso();
    };

    // RF04, gatilho 3: abertura a frio. O Flutter não emite `resumed` para o
    // estado inicial, então sem isto o app só avaliaria depois de o usuário
    // sair e voltar — justamente o cenário "reabrir o app" do requisito.
    _avaliarUso();
  }

  /// Mede, e manda o delta para o ÚNICO ponto de escrita de energia.
  ///
  /// O ControladorUso calcula mas não aplica; `lib/uso/` só mede. A aplicação
  /// acontece exclusivamente no ControladorMascote.
  Future<void> _avaliarUso() async {
    final delta = await _controladorUso.avaliar();
    if (delta != 0) {
      await _controladorMascote.registrarPenalidadeUso(delta);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlador.dispose();
    _controladorMascote.dispose();
    _controladorUso.dispose();
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

    // RF04, gatilho 1: voltou para o primeiro plano, hora de remedir o uso.
    // Não interfere no RNF01 — `resumed` continua não encerrando sessão.
    if (state == AppLifecycleState.resumed) {
      _avaliarUso();
    }
  }

  /// RF04, item 7: linha única de status. Sem tela nova.
  Widget _statusRedesSociais() {
    if (!_controladorUso.permissaoConcedida) {
      // Item 6: sem permissão não se penaliza, mas o usuário precisa saber.
      // O botão de conceder já existe na tela de diagnóstico (ícone no
      // AppBar), então aqui basta sinalizar.
      return const Text(
        'Redes sociais hoje: permissão não concedida',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.orange),
      );
    }

    final minutos = _controladorUso.minutosHoje;
    final limite = RegrasEnergia.limiteDiarioRedesSociaisMinutos;

    return Text(
      'Redes sociais hoje: $minutos min / $limite min',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: minutos > limite ? Colors.redAccent : null,
        fontWeight: minutos > limite ? FontWeight.bold : null,
      ),
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
        listenable: Listenable.merge(
          [_controlador, _controladorMascote, _controladorUso],
        ),
        builder: (context, _) {
          // Rolável: com o mascote no topo, o conteúdo fixo já não cabe na
          // altura de um celular pequeno. Column solta estourava o layout.
          //
          // O padding inferior soma a barra de navegação do Android. Vai no
          // scroll, e não num SafeArea em volta: assim a lista rola até o fim
          // e o último item para acima da barra, em vez de o viewport inteiro
          // encolher.
          final recuoInferior = MediaQuery.viewPaddingOf(context).bottom;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + recuoInferior),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WidgetMascote(mascote: _controladorMascote.mascote),
                const SizedBox(height: 8),
                _statusRedesSociais(),
                const Divider(height: 32),
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
                if (_historicoSalvo.isNotEmpty) ...[
                  const Divider(height: 32),
                  ..._historico(),
                ],
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

  /// Histórico persistido (Hive), já da sessão mais recente para a mais antiga.
  ///
  /// Itens construídos de uma vez, dentro do scroll da página, em vez de um
  /// ListView aninhado: no MVP a lista é curta e assim não há dois scrolls
  /// disputando o gesto.
  List<Widget> _historico() {
    return [
      for (final s in _historicoSalvo)
        ListTile(
          dense: true,
          leading: Icon(
            s.foiConcluida ? Icons.check_circle : Icons.cancel,
            color: s.foiConcluida ? Colors.green : Colors.redAccent,
          ),
          title: Text('${s.duracaoAlvo.inMinutes} min — ${s.status.rotulo}'),
          subtitle: Text('real: ${_formatar(s.duracaoReal)}'),
        ),
    ];
  }
}
