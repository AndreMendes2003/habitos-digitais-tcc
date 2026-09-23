import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

import 'sessao_foco.dart';

/// Estado do ciclo de uma sessão de foco na tela.
enum EstadoSessao { ocioso, emAndamento, finalizada }

/// Regra de negócio do RF02 (sessão de foco) e do RNF01 (detecção de saída).
///
/// Não conhece widgets: a tela é quem registra o [WidgetsBindingObserver] e
/// repassa os eventos para [aoMudarCicloDeVida]. Isso mantém a máquina de
/// estados testável sem device.
class ControladorSessao extends ChangeNotifier {
  ControladorSessao({DateTime Function()? relogio})
      : _relogio = relogio ?? DateTime.now;

  /// Durações oferecidas na tela (RF02, item 1).
  static const List<Duration> duracoesDisponiveis = [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 25),
  ];

  /// Fonte de tempo injetável — em teste permite avançar o relógio sem esperar.
  final DateTime Function() _relogio;

  /// Ponto de integração com o RF01 (mascote/ENERGIA) e com o Hive.
  ///
  /// O controlador da sessão NÃO calcula energia — apenas emite o resultado.
  /// Quem consome decide: [StatusSessao.concluida] soma (RF03),
  /// [StatusSessao.interrompida] subtrai (RF04). Ver [SessaoFoco.proporcaoCumprida].
  void Function(SessaoFoco sessao)? aoFinalizarSessao;

  Duration _duracaoAlvo = duracoesDisponiveis.last;
  EstadoSessao _estado = EstadoSessao.ocioso;
  DateTime? _inicioEm;
  Timer? _ticker;
  SessaoFoco? _ultimaSessao;

  Duration get duracaoAlvo => _duracaoAlvo;
  EstadoSessao get estado => _estado;

  /// Apenas a sessão recém-encerrada, para exibir o resultado.
  /// O histórico completo é do RepositorioSessoes.
  SessaoFoco? get ultimaSessao => _ultimaSessao;

  bool get emAndamento => _estado == EstadoSessao.emAndamento;

  /// Tempo decorrido por relógio de parede desde o início.
  Duration get duracaoDecorrida {
    final inicio = _inicioEm;
    if (inicio == null) return Duration.zero;
    final decorrido = _relogio().difference(inicio);
    return decorrido.isNegative ? Duration.zero : decorrido;
  }

  /// Contador regressivo exibido na tela. Nunca fica negativo.
  Duration get tempoRestante {
    if (_estado != EstadoSessao.emAndamento) return _duracaoAlvo;
    final restante = _duracaoAlvo - duracaoDecorrida;
    return restante.isNegative ? Duration.zero : restante;
  }

  void selecionarDuracao(Duration duracao) {
    if (emAndamento) return;
    _duracaoAlvo = duracao;
    notifyListeners();
  }

  void iniciar() {
    if (emAndamento) return;
    _inicioEm = _relogio();
    _estado = EstadoSessao.emAndamento;
    _ultimaSessao = null;
    _ticker?.cancel();
    // O tick só atualiza a UI e checa o fim; a contagem em si vem do relógio.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      verificarProgresso();
      notifyListeners();
    });
    notifyListeners();
  }

  /// Verifica se o alvo foi atingido com o app em primeiro plano (RF02, item 3).
  void verificarProgresso() {
    if (!emAndamento) return;
    if (duracaoDecorrida >= _duracaoAlvo) {
      _finalizar(StatusSessao.concluida);
    }
  }

  /// Recebe as transições de ciclo de vida vindas da tela (RNF01).
  ///
  /// [telaLigada] é `PowerManager.isInteractive` no momento do evento,
  /// injetado por quem chama. Este controlador não conhece MethodChannel
  /// nenhum: ele recebe o fato e aplica a regra.
  ///
  /// O padrão é `true` — o comportamento anterior, e o erro conservador
  /// quando a informação não chegou. Assumir a tela apagada manteria viva
  /// uma sessão realmente abandonada, inflando as sessões concluídas.
  void aoMudarCicloDeVida(
    AppLifecycleState estadoApp, {
    bool telaLigada = true,
  }) {
    if (!emAndamento) return;

    // RNF01: no Android, apenas `paused` significa que o app realmente perdeu
    // o primeiro plano — o usuário foi para a home ou trocou de app.
    //
    // `inactive` NÃO é saída: dispara quando o usuário puxa a barra de
    // notificação, recebe uma chamada ou o sistema abre um diálogo por cima.
    // A Activity segue em primeiro plano e volta sozinha. Tratar isso como
    // interrupção geraria falso positivo, classificando como abandono uma
    // sessão que o usuário não abandonou.
    //
    // `hidden` também não: é estado de transição, emitido no caminho
    // resumed -> inactive -> hidden -> paused, então dispararia nos mesmos
    // falsos positivos acima. Quando a saída for real, o `paused` vem logo
    // em seguida e é ele quem encerra a sessão.
    //
    // `detached` chega só depois de `paused` no Android, então a sessão já
    // terá sido encerrada quando ele acontecer.
    //
    // TELA APAGADA NÃO É SAÍDA. Apertar o botão de energia, ou deixar a tela
    // apagar sozinha, emite o mesmo `paused` de quem foi para a home. Mas
    // bloquear o celular é precisamente o que o app quer incentivar —
    // encerrar a sessão aí seria punir o acerto. Com a tela apagada a sessão
    // segue pelo relógio de parede, e o `resumed` abaixo decide o desfecho.
    if (estadoApp == AppLifecycleState.paused && telaLigada) {
      _finalizar(StatusSessao.interrompida);
    }

    // O ticker não roda com o app em segundo plano: o Flutter suspende os
    // timers. Uma sessão que atingiu o alvo com a tela apagada só descobre
    // isso agora — e sem esta checagem ela voltaria em andamento, com o
    // contador zerado e sem nunca concluir.
    //
    // `duracaoDecorrida` é relógio de parede, então o tempo com a tela
    // apagada conta normalmente.
    if (estadoApp == AppLifecycleState.resumed) {
      verificarProgresso();
    }
  }

  /// Volta ao estado inicial para permitir uma nova sessão.
  void reiniciar() {
    if (emAndamento) return;
    _estado = EstadoSessao.ocioso;
    _inicioEm = null;
    _ultimaSessao = null;
    notifyListeners();
  }

  void _finalizar(StatusSessao status) {
    _ticker?.cancel();
    _ticker = null;

    final decorrida = duracaoDecorrida;
    final sessao = SessaoFoco(
      duracaoAlvo: _duracaoAlvo,
      // Numa sessão concluída o tick pode passar alguns ms do alvo; limitamos
      // para o registro não sugerir foco além do que foi pedido.
      duracaoReal: status == StatusSessao.concluida && decorrida > _duracaoAlvo
          ? _duracaoAlvo
          : decorrida,
      inicioEm: _inicioEm ?? _relogio(),
      status: status,
    );

    _ultimaSessao = sessao;
    _estado = EstadoSessao.finalizada;

    // RF03/RF04: daqui o resultado segue para a ENERGIA do mascote e para o
    // RepositorioSessoes — este controlador não guarda histórico.
    aoFinalizarSessao?.call(sessao);

    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
