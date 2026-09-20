import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../diagnostico/tela_diagnostico_uso.dart';
import '../dominio/controlador_sessao.dart';
import '../dominio/regras_energia.dart';
import '../estado/estado_mascote.dart';
import 'componentes/botao_principal.dart';
import 'tema/cores.dart';
import 'tema/espacamento.dart';
import 'tema/tipografia.dart';
import 'widget_mascote.dart';

/// Padrão todo numérico: não depende de dados de locale, então dispensa
/// `initializeDateFormatting()`.
final DateFormat _formatoInicio = DateFormat('dd/MM/yyyy HH:mm');

/// Tela única do RF02 + RF01. Sem polimento: o objetivo é evidenciar o
/// comportamento.
///
/// Não recebe nada: todo o estado vem do [EstadoApp] registrado acima do
/// MaterialApp. Quem monta a tela — `main.dart` ou o teste de widget — é
/// responsável por registrar o provider e por descartar o estado.
class TelaFoco extends StatefulWidget {
  const TelaFoco({super.key});

  @override
  State<TelaFoco> createState() => _TelaFocoState();
}

/// Stateful só pelo [WidgetsBindingObserver]: o ciclo de vida do Android é a
/// única coisa que a tela ainda precisa escutar por conta própria. Nenhum
/// estado de domínio mora aqui.
class _TelaFocoState extends State<TelaFoco> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// RNF01: única ponte entre o ciclo de vida do Android e o domínio.
  /// O critério de qual estado conta como saída mora no ControladorSessao.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<EstadoApp>().aoMudarCicloDeVida(state);
  }

  @override
  Widget build(BuildContext context) => const _CorpoFoco();
}

class _CorpoFoco extends StatelessWidget {
  const _CorpoFoco();

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
      // Consumer, e não um watch no topo: só o corpo repinta a cada tick da
      // sessão, como acontecia com o ListenableBuilder que estava aqui.
      body: Consumer<EstadoApp>(
        builder: (context, estado, _) {
          // Rolável: com o mascote no topo, o conteúdo fixo já não cabe na
          // altura de um celular pequeno. Column solta estourava o layout.
          //
          // O padding inferior soma a barra de navegação do Android. Vai no
          // scroll, e não num SafeArea em volta: assim a lista rola até o fim
          // e o último item para acima da barra, em vez de o viewport inteiro
          // encolher.
          final recuoInferior = MediaQuery.viewPaddingOf(context).bottom;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              Espacamento.lg,
              Espacamento.lg,
              Espacamento.lg,
              Espacamento.lg + recuoInferior,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WidgetMascote(mascote: estado.mascote),
                const SizedBox(height: Espacamento.sm),
                _statusRedesSociais(context, estado),
                const Divider(height: Espacamento.xxl),
                _seletorDuracao(estado),
                const SizedBox(height: Espacamento.xl),
                Center(
                  child: Text(
                    _formatar(estado.tempoRestante),
                    style: Tipografia.cronometro,
                  ),
                ),
                const SizedBox(height: Espacamento.xl),
                _botaoPrincipal(estado),
                const SizedBox(height: Espacamento.xl),
                _resultado(estado),
                if (estado.historico.isNotEmpty) ...[
                  const Divider(height: Espacamento.xxl),
                  ..._historico(estado),
                ],
              ],
            ),
          );
        },
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
      // O botão de conceder já existe na tela de diagnóstico (ícone no
      // AppBar), então aqui basta sinalizar.
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
  List<Widget> _historico(EstadoApp estado) {
    return [
      for (final s in estado.historico)
        ListTile(
          dense: true,
          leading: Icon(
            s.foiConcluida ? Icons.check_circle : Icons.cancel,
            color: s.foiConcluida ? Cores.feliz : Cores.cansado,
          ),
          title: Text('${s.duracaoAlvo.inMinutes} min — ${s.status.rotulo}'),
          subtitle: Text('real: ${_formatar(s.duracaoReal)}'),
        ),
    ];
  }

  String _formatar(Duration d) {
    final minutos = d.inMinutes.toString().padLeft(2, '0');
    final segundos = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }
}
