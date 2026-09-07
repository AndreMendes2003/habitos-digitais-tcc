import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dominio/controlador_sessao.dart';
import 'package:habitos_digitais/dominio/sessao_foco.dart';

void main() {
  /// Relógio controlado: evita esperar 25 minutos reais no teste.
  late DateTime agora;
  late ControladorSessao controlador;

  ControladorSessao criar() {
    final c = ControladorSessao(relogio: () => agora);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    agora = DateTime(2026, 9, 7, 10, 0, 0);
    controlador = criar();
  });

  test('comeca ocioso com a duracao alvo padrao', () {
    expect(controlador.estado, EstadoSessao.ocioso);
    expect(controlador.tempoRestante, controlador.duracaoAlvo);
    expect(controlador.ultimaSessao, isNull);
  });

  test('nao troca a duracao com sessao em andamento', () {
    controlador.selecionarDuracao(const Duration(minutes: 5));
    controlador.iniciar();
    controlador.selecionarDuracao(const Duration(minutes: 25));

    expect(controlador.duracaoAlvo, const Duration(minutes: 5));
  });

  test('contador regressivo acompanha o relogio de parede', () {
    controlador.selecionarDuracao(const Duration(minutes: 5));
    controlador.iniciar();

    agora = agora.add(const Duration(minutes: 2));

    expect(controlador.tempoRestante, const Duration(minutes: 3));
  });

  test('RF02: zerar o contador em primeiro plano marca CONCLUIDA', () {
    controlador.selecionarDuracao(const Duration(minutes: 5));
    controlador.iniciar();

    agora = agora.add(const Duration(minutes: 5, seconds: 1));
    controlador.verificarProgresso();

    final sessao = controlador.ultimaSessao!;
    expect(sessao.status, StatusSessao.concluida);
    expect(sessao.duracaoAlvo, const Duration(minutes: 5));
    // Limitado ao alvo: o tick pode passar alguns segundos.
    expect(sessao.duracaoReal, const Duration(minutes: 5));
    expect(sessao.proporcaoCumprida, 1.0);
    expect(controlador.estado, EstadoSessao.finalizada);
  });

  test('RNF01: sair para segundo plano (paused) marca INTERROMPIDA', () {
    controlador.selecionarDuracao(const Duration(minutes: 25));
    controlador.iniciar();

    agora = agora.add(const Duration(minutes: 3));
    controlador.aoMudarCicloDeVida(AppLifecycleState.paused);

    final sessao = controlador.ultimaSessao!;
    expect(sessao.status, StatusSessao.interrompida);
    expect(sessao.duracaoReal, const Duration(minutes: 3));
    expect(sessao.proporcaoCumprida, closeTo(3 / 25, 0.001));
  });

  test('RNF01: inactive NAO interrompe (barra de notificacao, chamada)', () {
    controlador.iniciar();
    controlador.aoMudarCicloDeVida(AppLifecycleState.inactive);

    expect(controlador.ultimaSessao, isNull);
    expect(controlador.emAndamento, isTrue);
  });

  test('RNF01: hidden NAO interrompe (estado de transicao)', () {
    controlador.iniciar();
    controlador.aoMudarCicloDeVida(AppLifecycleState.hidden);

    expect(controlador.ultimaSessao, isNull);
    expect(controlador.emAndamento, isTrue);
  });

  test('RNF01: detached NAO interrompe (no Android vem depois do paused)', () {
    controlador.iniciar();
    controlador.aoMudarCicloDeVida(AppLifecycleState.detached);

    expect(controlador.ultimaSessao, isNull);
    expect(controlador.emAndamento, isTrue);
  });

  test('RNF01: na sequencia do Android, so o paused encerra', () {
    controlador.selecionarDuracao(const Duration(minutes: 25));
    controlador.iniciar();

    // Caminho real emitido pelo Android ao sair do app.
    agora = agora.add(const Duration(minutes: 2));
    controlador.aoMudarCicloDeVida(AppLifecycleState.inactive);
    expect(controlador.emAndamento, isTrue);

    agora = agora.add(const Duration(minutes: 1));
    controlador.aoMudarCicloDeVida(AppLifecycleState.hidden);
    expect(controlador.emAndamento, isTrue);

    agora = agora.add(const Duration(minutes: 1));
    controlador.aoMudarCicloDeVida(AppLifecycleState.paused);

    final sessao = controlador.ultimaSessao!;
    expect(sessao.status, StatusSessao.interrompida);
    // 4 min, nao 2: o tempo com a barra aberta conta como foco.
    expect(sessao.duracaoReal, const Duration(minutes: 4));
  });

  test('RNF01: inactive seguido de resumed mantem a sessao viva', () {
    controlador.selecionarDuracao(const Duration(minutes: 25));
    controlador.iniciar();

    // Usuario puxou a barra de notificacao e fechou sem sair do app.
    controlador.aoMudarCicloDeVida(AppLifecycleState.inactive);
    agora = agora.add(const Duration(minutes: 5));
    controlador.aoMudarCicloDeVida(AppLifecycleState.resumed);

    expect(controlador.emAndamento, isTrue);
    expect(controlador.ultimaSessao, isNull);
    expect(controlador.tempoRestante, const Duration(minutes: 20));
  });

  test('resumed nao encerra a sessao', () {
    controlador.iniciar();
    controlador.aoMudarCicloDeVida(AppLifecycleState.resumed);

    expect(controlador.emAndamento, isTrue);
  });

  test('ciclo de vida nao afeta sessao ja finalizada', () {
    controlador.selecionarDuracao(const Duration(minutes: 5));
    controlador.iniciar();
    agora = agora.add(const Duration(minutes: 6));
    controlador.verificarProgresso();

    controlador.aoMudarCicloDeVida(AppLifecycleState.paused);

    expect(controlador.ultimaSessao?.status, StatusSessao.concluida);
    expect(controlador.historico, hasLength(1));
  });

  test('RF03/RF04: o resultado e emitido no ponto de integracao da ENERGIA', () {
    SessaoFoco? recebida;
    controlador.aoFinalizarSessao = (s) => recebida = s;

    controlador.selecionarDuracao(const Duration(minutes: 5));
    controlador.iniciar();
    agora = agora.add(const Duration(minutes: 5));
    controlador.verificarProgresso();

    expect(recebida, isNotNull);
    expect(recebida!.status, StatusSessao.concluida);
  });

  test('historico acumula as sessoes da execucao', () {
    controlador.selecionarDuracao(const Duration(minutes: 5));

    controlador.iniciar();
    agora = agora.add(const Duration(minutes: 1));
    controlador.aoMudarCicloDeVida(AppLifecycleState.paused);

    controlador.reiniciar();
    controlador.iniciar();
    agora = agora.add(const Duration(minutes: 5));
    controlador.verificarProgresso();

    expect(controlador.historico.map((s) => s.status), [
      StatusSessao.interrompida,
      StatusSessao.concluida,
    ]);
  });
}
