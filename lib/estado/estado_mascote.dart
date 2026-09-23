/// Camada de estado única da UI, sobre os controladores de domínio.
///
/// NOME DA CLASSE: `EstadoApp`, e não `EstadoMascote`, porque
/// `EstadoMascote` já é o enum da FSM em `dominio/mascote.dart` (Feliz/
/// Neutro/Cansado). Duas coisas diferentes com o mesmo nome num projeto que
/// fala de "estado do mascote" o tempo todo seria convite a erro de leitura.
/// O arquivo mantém o nome pedido.
///
/// O QUE ESTA CLASSE É: um agregador. Ela junta os três controladores que a
/// tela já usava soltos e reexporta o que a UI precisa, em getters
/// somente-leitura. Nada de regra aqui.
///
/// O QUE ELA NÃO É: não calcula energia, não deriva FSM, não fala com o Hive.
/// O ControladorMascote continua sendo o ÚNICO ponto de escrita de energia —
/// esta classe só delega. Os limiares e deltas continuam morando em
/// RegrasEnergia, sem cópia nenhuma aqui.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;

import '../dados/repositorio_historico.dart';
import '../dados/repositorio_mascote.dart';
import '../dados/repositorio_sessoes.dart';
import '../dados/repositorio_uso.dart';
import '../dominio/controlador_mascote.dart';
import '../dominio/controlador_sessao.dart';
import '../dominio/calculo_sequencia.dart';
import '../dominio/captura_baseline.dart';
import '../dominio/controlador_uso.dart';
import '../dominio/mascote.dart';
import '../dominio/registro_diario.dart';
import '../dominio/sessao_foco.dart';
import '../uso/medicao_uso.dart';

class EstadoApp extends ChangeNotifier {
  EstadoApp({
    required RepositorioMascote repositorioMascote,
    required RepositorioSessoes repositorioSessoes,
    required RepositorioUso repositorioUso,
    required RepositorioHistorico repositorioHistorico,
    required Future<MedicaoUso> Function() medirUso,
    CapturaBaseline? capturaBaseline,
    DateTime Function()? relogio,
    void Function(VoidCallback)? agendarAberturaAFrio,
  })  : _agendarAberturaAFrio =
            agendarAberturaAFrio ?? _depoisDoPrimeiroFrame,
        // ignore: prefer_initializing_formals
        _capturaBaseline = capturaBaseline,
        // ignore: prefer_initializing_formals
        _repositorioHistorico = repositorioHistorico,
        _relogio = relogio ?? DateTime.now,
        // Formal inicializador (`this._repositorioSessoes`) deixaria o nome
        // privado vazando para quem constroi a classe.
        // ignore: prefer_initializing_formals
        _repositorioSessoes = repositorioSessoes,
        _controladorSessao = ControladorSessao(),
        _controladorMascote = ControladorMascote(
          inicial: repositorioMascote.carregar(),
          aoPersistir: repositorioMascote.salvar,
        ),
        _controladorUso = ControladorUso(
          medir: medirUso,
          avaliacaoInicial: repositorioUso.carregar(),
          aoPersistir: repositorioUso.salvar,
        ) {
    _historico = _repositorioSessoes.todas();
    _historicoDiario = _repositorioHistorico.todos();

    // Um único repasse: cada controlador já notifica quando muda, e aqui isso
    // vira uma notificação só para a UI. Evita reimplementar, em cada ação,
    // a decisão de quando avisar — que é justamente onde se esquece uma.
    _controladorSessao.addListener(notifyListeners);
    _controladorMascote.addListener(notifyListeners);
    _controladorUso.addListener(notifyListeners);

    // RF03/RF04: é aqui que o resultado da sessão vira ENERGIA e vai para o
    // disco. Saiu de dentro do State da tela sem mudar de ordem.
    _controladorSessao.aoFinalizarSessao = (sessao) async {
      debugPrint('[RF02] $sessao');
      await _controladorMascote.registrarSessao(sessao);
      await _repositorioSessoes.adicionar(sessao);
      _historico = _repositorioSessoes.todas();
      notifyListeners();
      // RF04, gatilho 2: fim de sessão.
      await avaliarUso();
    };

    // RF04, gatilho 3: abertura a frio. O Flutter não emite `resumed` para o
    // estado inicial, então sem isto o app só avaliaria depois de o usuário
    // sair e voltar — justamente o cenário "reabrir o app" do requisito.
    //
    // AGENDADO, e não chamado direto: a consulta ao UsageStatsManager é um
    // salto para o lado Android e volta, e disparada aqui ela cai no meio da
    // construção da primeira árvore de widgets — ~57 frames pulados no S23.
    // Depois do primeiro frame o usuário já vê a tela, com os minutos em
    // "medindo..." até a medida chegar.
    primeiraAvaliacao = _aberturaAFrio();
  }

  /// Agendamento padrão do gatilho de abertura a frio: o primeiro frame
  /// desenha antes de qualquer consulta de uso.
  static void _depoisDoPrimeiroFrame(VoidCallback acao) {
    WidgetsBinding.instance.addPostFrameCallback((_) => acao());
  }

  /// Injetável para que os testes disparem a abertura a frio na hora, sem
  /// depender de um frame que só existe em teste de widget.
  final void Function(VoidCallback) _agendarAberturaAFrio;

  /// Embrulha [avaliarUso] num Completer para que [primeiraAvaliacao]
  /// continue sendo aguardável mesmo saindo do construtor já adiada. O
  /// `complete(Future)` repassa erro também — engolir aqui esconderia uma
  /// falha de medição no boot.
  Future<void> _aberturaAFrio() {
    final concluida = Completer<void>();
    _agendarAberturaAFrio(() => concluida.complete(avaliarUso()));
    return concluida.future;
  }

  final RepositorioSessoes _repositorioSessoes;
  final RepositorioHistorico _repositorioHistorico;

  /// Captura retroativa da linha de base, na primeira medição válida.
  ///
  /// Nulo quando não há captura a fazer — é uma etapa opcional do boot, não
  /// um segundo caminho para o que o resto do EstadoApp já faz.
  final CapturaBaseline? _capturaBaseline;

  /// Só o RF07 usa este relógio. Os controladores seguem com os deles, para
  /// que injetar um relógio aqui não mexa na contagem da sessão de foco.
  final DateTime Function() _relogio;

  final ControladorSessao _controladorSessao;
  final ControladorMascote _controladorMascote;
  final ControladorUso _controladorUso;

  /// Gatilho de abertura a frio, agendado no construtor para depois do
  /// primeiro frame.
  ///
  /// Exposto porque o construtor não pode ser `async` e mesmo assim inicia
  /// trabalho que termina em disco: sem isto, nada no app consegue saber
  /// quando a primeira avaliação acabou — e fechar as caixas do Hive antes
  /// dela terminar estoura com "Box has already been closed".
  late final Future<void> primeiraAvaliacao;

  /// Falso até a PRIMEIRA avaliação terminar, qualquer que seja o desfecho
  /// — inclusive permissão negada. Separa "ainda não sei" de "medi, deu 0",
  /// que na tela são a mesma coisa se olharmos só os minutos.
  bool _primeiraMedicaoConcluida = false;

  List<SessaoFoco> _historico = const [];

  /// Cache do histórico diário. Reler a caixa em cada getter faria disco a
  /// cada repintura; a caixa só é relida quando o dia corrente é gravado.
  List<RegistroDiario> _historicoDiario = const [];

  // --- Mascote (RF01) -------------------------------------------------------

  /// O modelo inteiro, para o WidgetMascote. Imutável: a UI não tem como
  /// escrever energia por aqui.
  Mascote get mascote => _controladorMascote.mascote;

  int get energia => mascote.energia;

  /// Estado DERIVADO da energia. Continua sem ser armazenado em lugar nenhum.
  EstadoMascote get estadoMascote => mascote.estado;

  double get proporcaoEnergia => mascote.proporcaoEnergia;

  // --- Sessão de foco (RF02) ------------------------------------------------

  bool get sessaoEmAndamento => _controladorSessao.emAndamento;

  EstadoSessao get estadoSessao => _controladorSessao.estado;

  Duration get tempoRestante => _controladorSessao.tempoRestante;

  Duration get duracaoAlvo => _controladorSessao.duracaoAlvo;

  SessaoFoco? get ultimaSessao => _controladorSessao.ultimaSessao;

  /// Histórico persistido, da sessão mais recente para a mais antiga.
  List<SessaoFoco> get historico => _historico;

  // --- Uso de redes sociais (RF04) ------------------------------------------

  int get minutosRedesSociaisHoje => _controladorUso.minutosHoje;

  /// A medição de hoje ainda não chegou. Enquanto for `true`, os minutos e a
  /// permissão não significam nada — são o valor inicial, não uma medida.
  bool get medicaoUsoPendente => !_primeiraMedicaoConcluida;

  bool get permissaoUsoConcedida => _controladorUso.permissaoConcedida;

  // --- Histórico diário e sequência (RF07) ----------------------------------

  /// Dias consecutivos dentro do limite até hoje. Lacuna atravessa.
  int get sequenciaAtual =>
      CalculoSequencia.atual(_historicoDiario, _relogio());

  /// Maior sequência já alcançada, a corrente inclusive.
  int get maiorSequencia =>
      CalculoSequencia.maior(_historicoDiario, _relogio());

  /// Registros dos últimos 30 dias em ordem cronológica. Dias sem registro
  /// simplesmente não aparecem — a ausência É a lacuna.
  List<RegistroDiario> get ultimos30Dias =>
      CalculoSequencia.ultimosDias(_historicoDiario, _relogio());

  /// Os últimos 30 dias com UM item por dia, buracos inclusive.
  ///
  /// Serve à grade da aba Sequência. Mora aqui, e não na tela, porque montar
  /// a janela exige saber que dia é hoje — e o relógio é injetado neste
  /// nível, não no widget.
  List<DiaDaSequencia> get gradeUltimos30Dias =>
      CalculoSequencia.grade(_historicoDiario, _relogio());

  // --- Ações que a tela dispara ---------------------------------------------

  void selecionarDuracao(Duration duracao) =>
      _controladorSessao.selecionarDuracao(duracao);

  void iniciarSessao() => _controladorSessao.iniciar();

  void reiniciarSessao() => _controladorSessao.reiniciar();

  /// RNF01: única ponte entre o ciclo de vida do Android e o domínio.
  ///
  /// NÃO existe interrupção manual no MVP: a sessão só é interrompida quando
  /// o Android emite `paused`. O critério de qual estado conta como saída
  /// mora no ControladorSessao e não é reimplementado aqui.
  void aoMudarCicloDeVida(AppLifecycleState estadoApp) {
    // TODO(remover antes da entrega): log de diagnóstico do RNF01.
    // Levanta, no Samsung, quais estados o Android emite em cada cenário
    // (barra de notificação, chamada, Home, switcher, tela apagando). A ação
    // é deduzida comparando o antes/depois, e não reimplementando a regra de
    // `paused`.
    final estavaAtiva = _controladorSessao.emAndamento;

    _controladorSessao.aoMudarCicloDeVida(estadoApp);

    final acao = estavaAtiva && !_controladorSessao.emAndamento
        ? 'interrompido'
        : 'ignorado';
    debugPrint(
      '[LIFECYCLE] estado recebido: ${estadoApp.name} '
      '| sessão ativa: ${estavaAtiva ? 'sim' : 'não'} '
      '| ação: $acao',
    );

    // RF04, gatilho 1: voltou para o primeiro plano, hora de remedir o uso.
    // Não interfere no RNF01 — `resumed` continua não encerrando sessão.
    if (estadoApp == AppLifecycleState.resumed) {
      avaliarUso();
    }
  }

  /// Mede, e manda o delta para o ÚNICO ponto de escrita de energia.
  ///
  /// O ControladorUso calcula mas não aplica; `lib/uso/` só mede. A aplicação
  /// acontece exclusivamente no ControladorMascote.
  Future<void> avaliarUso() async {
    final delta = await _controladorUso.avaliar();
    if (delta != 0) {
      await _controladorMascote.registrarPenalidadeUso(delta);
    }
    await _registrarDiaCorrente();
    await _capturarBaselineSePrecisar();

    if (!_primeiraMedicaoConcluida) {
      _primeiraMedicaoConcluida = true;
      notifyListeners();
    }
  }

  /// Linha de base: os dias anteriores à instalação, capturados na PRIMEIRA
  /// medição válida.
  ///
  /// Só com permissão concedida. Sem ela a varredura devolveria sete lacunas
  /// e marcaria a captura como feita — queimando a única chance de registrar
  /// a linha de base quando o usuário conceder a permissão depois.
  Future<void> _capturarBaselineSePrecisar() async {
    final captura = _capturaBaseline;
    if (captura == null || !_controladorUso.permissaoConcedida) return;

    final gravados = await captura.capturarSeNecessario(_relogio());
    if (gravados == 0) return;

    _historicoDiario = _repositorioHistorico.todos();
    notifyListeners();
  }

  /// RF07: grava/atualiza o registro de hoje.
  ///
  /// Pendurado no FIM de [avaliarUso], e em nenhum outro lugar: assim o
  /// histórico herda de graça os três gatilhos do RF04 (abertura a frio,
  /// retorno ao primeiro plano, fim de sessão) e a idempotência que já existe
  /// lá. Um segundo caminho de escrita abriria a porta para dois registros do
  /// mesmo dia discordando entre si.
  ///
  /// A chave é a data, então reescrever o dia corrente é `put` no mesmo
  /// registro — o dia vai sendo corrigido conforme avança.
  Future<void> _registrarDiaCorrente() async {
    final hoje = _relogio();
    final diaCorrente = RegistroDiario.apenasData(hoje);

    final sessoesDeHoje = _historico.where(
      (sessao) => RegistroDiario.apenasData(sessao.inicioEm) == diaCorrente,
    );

    final registro = RegistroDiario(
      dia: hoje,
      minutosRedesSociais: _controladorUso.minutosHoje,
      sessoesConcluidas: sessoesDeHoje.where((s) => s.foiConcluida).length,
      sessoesInterrompidas: sessoesDeHoje.where((s) => !s.foiConcluida).length,
      energiaFinal: _controladorMascote.mascote.energia,
      // Sem permissão não houve leitura: o dia entra como LACUNA, não como
      // dia cumprido com zero minuto.
      houveMedicao: _controladorUso.permissaoConcedida,
    );

    // Só grava se algo mudou de fato — mesma guarda que o ControladorUso já
    // aplica à avaliação diária. A avaliação dispara em todo resume; sem
    // isto, abrir e fechar o app faria uma escrita em disco por vez sem
    // nenhum dado novo.
    if (_repositorioHistorico.carregarDia(diaCorrente) == registro) return;

    await _repositorioHistorico.salvar(registro);
    _historicoDiario = _repositorioHistorico.todos();
    notifyListeners();
  }

  @override
  void dispose() {
    _controladorSessao.removeListener(notifyListeners);
    _controladorMascote.removeListener(notifyListeners);
    _controladorUso.removeListener(notifyListeners);
    _controladorSessao.dispose();
    _controladorMascote.dispose();
    _controladorUso.dispose();
    super.dispose();
  }
}
