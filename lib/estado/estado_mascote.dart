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

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

import '../dados/repositorio_mascote.dart';
import '../dados/repositorio_sessoes.dart';
import '../dados/repositorio_uso.dart';
import '../dominio/controlador_mascote.dart';
import '../dominio/controlador_sessao.dart';
import '../dominio/controlador_uso.dart';
import '../dominio/mascote.dart';
import '../dominio/sessao_foco.dart';
import '../uso/medicao_uso.dart';

class EstadoApp extends ChangeNotifier {
  EstadoApp({
    required RepositorioMascote repositorioMascote,
    required RepositorioSessoes repositorioSessoes,
    required RepositorioUso repositorioUso,
    required Future<MedicaoUso> Function() medirUso,
  })  :
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
    avaliarUso();
  }

  final RepositorioSessoes _repositorioSessoes;
  final ControladorSessao _controladorSessao;
  final ControladorMascote _controladorMascote;
  final ControladorUso _controladorUso;

  List<SessaoFoco> _historico = const [];

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

  bool get permissaoUsoConcedida => _controladorUso.permissaoConcedida;

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
