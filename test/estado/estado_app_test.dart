import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dados/repositorio_historico.dart';
import 'package:habitos_digitais/dados/repositorio_mascote.dart';
import 'package:habitos_digitais/dados/repositorio_sessoes.dart';
import 'package:habitos_digitais/dados/repositorio_uso.dart';
import 'package:habitos_digitais/dominio/regras_energia.dart';
import 'package:habitos_digitais/dominio/registro_diario.dart';
import 'package:habitos_digitais/dominio/sessao_foco.dart';
import 'package:habitos_digitais/estado/estado_mascote.dart';
import 'package:habitos_digitais/uso/medicao_uso.dart';
import 'package:hive/hive.dart';

/// RF07, requisito 2: o registro do dia é escrito nos MESMOS momentos em que
/// o RF04 já avalia o uso, sem um segundo caminho de escrita.
///
/// Teste de estado, não de widget: aqui não há zona fake-async, então a
/// escrita real no Hive completa normalmente.
/// Dispara a abertura a frio na hora, em vez de esperar o primeiro frame.
///
/// Em produção o gatilho é adiado para depois do primeiro frame (a consulta
/// ao UsageStatsManager travava o boot). Estes testes constroem o EstadoApp
/// fora de um teste de widget, onde frame nenhum é desenhado — sem isto,
/// `primeiraAvaliacao` nunca completaria.
void dispararJa(VoidCallback acao) => acao();

void main() {
  late Directory diretorio;
  late RepositorioMascote repositorioMascote;
  late RepositorioSessoes repositorioSessoes;
  late RepositorioUso repositorioUso;
  late RepositorioHistorico repositorioHistorico;
  late MedicaoUso medicao;
  EstadoApp? estado;

  /// Relógio fixo: os cenários falam em "hoje" e "ontem" e não podem depender
  /// de o teste rodar perto da meia-noite.
  final hoje = DateTime(2026, 9, 20, 15);
  final ontem = DateTime(2026, 9, 19, 15);

  setUp(() async {
    diretorio = await Directory.systemTemp.createTemp('habitos_estado_test');
    Hive.init(diretorio.path);
    repositorioMascote = RepositorioMascote(
      await Hive.openBox<int>(RepositorioMascote.nomeCaixa),
    );
    repositorioSessoes = RepositorioSessoes(
      await Hive.openBox<Map<dynamic, dynamic>>(RepositorioSessoes.nomeCaixa),
    );
    repositorioUso = RepositorioUso(
      await Hive.openBox<Map<dynamic, dynamic>>(RepositorioUso.nomeCaixa),
    );
    repositorioHistorico = RepositorioHistorico(
      await Hive.openBox<Map<dynamic, dynamic>>(
        RepositorioHistorico.nomeCaixa,
      ),
    );
    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 0);
    estado = null;
  });

  tearDown(() async {
    estado?.dispose();
    await Hive.deleteFromDisk();
    await Hive.close();
    if (diretorio.existsSync()) {
      diretorio.deleteSync(recursive: true);
    }
  });

  /// Constrói o EstadoApp e espera o gatilho de abertura a frio assentar.
  Future<EstadoApp> abrirApp() async {
    final novo = EstadoApp(
      repositorioMascote: repositorioMascote,
      repositorioSessoes: repositorioSessoes,
      repositorioUso: repositorioUso,
      repositorioHistorico: repositorioHistorico,
      medirUso: () async => medicao,
      relogio: () => hoje,
      agendarAberturaAFrio: dispararJa,
    );
    estado = novo;
    // Espera o gatilho de abertura a frio que o construtor disparou. Chamar
    // `avaliarUso()` de novo aqui não serviria: o ControladorUso
    // curto-circuita avaliações concorrentes e o teste leria estado pela
    // metade.
    await novo.primeiraAvaliacao;
    return novo;
  }

  /// Registros semeados direto na caixa, como se viessem de execuções
  /// anteriores do app.
  RegistroDiario diaCumprido(DateTime dia) => RegistroDiario(
        dia: dia,
        minutosRedesSociais: 10,
        sessoesConcluidas: 1,
        sessoesInterrompidas: 0,
        energiaFinal: 60,
        houveMedicao: true,
      );

  RegistroDiario diaLacuna(DateTime dia) =>
      RegistroDiario.lacuna(dia, energiaFinal: 60);

  SessaoFoco sessao(StatusSessao status, DateTime inicio) => SessaoFoco(
        duracaoAlvo: const Duration(minutes: 25),
        duracaoReal: const Duration(minutes: 25),
        inicioEm: inicio,
        status: status,
      );

  group('estado de carregamento da medição', () {
    test('pendente antes da primeira medição, resolvido depois', () async {
      medicao = const MedicaoUso(permissaoConcedida: true, minutos: 0);

      final app = EstadoApp(
        repositorioMascote: repositorioMascote,
        repositorioSessoes: repositorioSessoes,
        repositorioUso: repositorioUso,
        repositorioHistorico: repositorioHistorico,
        medirUso: () async => medicao,
        relogio: () => hoje,
        agendarAberturaAFrio: dispararJa,
      );
      estado = app;

      // Antes de a medição chegar, 0 minuto e "sem permissão" ainda não são
      // fatos — são o valor inicial dos campos.
      expect(app.medicaoUsoPendente, isTrue);

      await app.primeiraAvaliacao;

      expect(app.medicaoUsoPendente, isFalse);
      expect(app.minutosRedesSociaisHoje, 0);
    });

    test('permissão negada também resolve o carregamento', () async {
      // Sem permissão não há medida, mas há resposta: a tela precisa sair do
      // "medindo..." e mostrar o aviso de permissão.
      medicao = const MedicaoUso.semPermissao();

      final app = await abrirApp();

      expect(app.medicaoUsoPendente, isFalse);
      expect(app.permissaoUsoConcedida, isFalse);
    });

    test('notifica ao sair do carregamento', () async {
      medicao = const MedicaoUso(permissaoConcedida: true, minutos: 5);

      final app = EstadoApp(
        repositorioMascote: repositorioMascote,
        repositorioSessoes: repositorioSessoes,
        repositorioUso: repositorioUso,
        repositorioHistorico: repositorioHistorico,
        medirUso: () async => medicao,
        relogio: () => hoje,
        agendarAberturaAFrio: dispararJa,
      );
      estado = app;

      var avisos = 0;
      app.addListener(() => avisos++);

      await app.primeiraAvaliacao;

      // Sem notificação a tela ficaria em "medindo..." para sempre.
      expect(avisos, greaterThan(0));
      expect(app.medicaoUsoPendente, isFalse);
    });
  });

  group('adiamento da abertura a frio', () {
    test('nao mede antes do primeiro frame; mede quando ele chega', () async {
      var medicoes = 0;
      VoidCallback? agendada;

      final app = EstadoApp(
        repositorioMascote: repositorioMascote,
        repositorioSessoes: repositorioSessoes,
        repositorioUso: repositorioUso,
        repositorioHistorico: repositorioHistorico,
        medirUso: () async {
          medicoes++;
          return medicao;
        },
        relogio: () => hoje,
        // No lugar do addPostFrameCallback: guarda a acao em vez de rodar,
        // para o teste poder inspecionar o intervalo entre construir o
        // EstadoApp e o primeiro frame acontecer.
        agendarAberturaAFrio: (acao) => agendada = acao,
      );
      estado = app;

      // O construtor terminou. Se a consulta ao UsageStatsManager saisse
      // daqui, ela cairia dentro da construcao da primeira arvore de widgets
      // — que e exatamente o travamento do boot.
      expect(medicoes, 0);
      expect(app.medicaoUsoPendente, isTrue);
      expect(agendada, isNotNull);

      // O primeiro frame desenhou: agora sim.
      agendada!();
      await app.primeiraAvaliacao;

      expect(medicoes, 1);
      expect(app.medicaoUsoPendente, isFalse);
    });
  });

  group('log [LIFECYCLE]', () {
    /// Roda [acao] com o debugPrint capturado e devolve a linha do evento.
    ///
    /// O log do RNF01 e a evidencia que vai para o artigo: se ele
    /// contradisser o registro gravado, a evidencia e que esta errada.
    ///
    /// Filtra por 'estado recebido' porque o ServicoTela tambem escreve com
    /// o prefixo [LIFECYCLE] quando o canal nao responde — e em teste ele
    /// nunca responde.
    Future<String> capturarEvento(Future<void> Function() acao) async {
      final linhas = <String>[];
      final original = debugPrint;
      debugPrint = (String? mensagem, {int? wrapWidth}) {
        linhas.add(mensagem ?? '');
      };
      try {
        await acao();
      } finally {
        debugPrint = original;
      }
      return linhas.firstWhere((l) => l.contains('[LIFECYCLE] estado recebido'));
    }

    /// Espera o encadeamento do fim de sessao assentar em disco.
    ///
    /// `aoFinalizarSessao` nao e aguardado por quem o dispara: energia, Hive
    /// e avaliarUso correm depois que o metodo ja voltou. Fechar as caixas
    /// antes disso estoura com "Box has already been closed" — e o numero de
    /// drenagens necessario nao e algo que se acerte por tentativa.
    ///
    /// Espera pelo RepositorioSessoes, e nao pelo registro diario: o relogio
    /// injetado aqui e o do EstadoApp (RF07), enquanto o ControladorSessao
    /// mantem o proprio, de propósito. A sessao nasce com a data real e por
    /// isso nao entra na contagem do dia `hoje` fixado no teste.
    Future<void> esperarSessaoGravada() async {
      final limite = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(limite)) {
        if (repositorioSessoes.todas().isNotEmpty) {
          // Rabicho: avaliarUso ainda corre depois da gravacao da sessao.
          for (var i = 0; i < 5; i++) {
            await Future<void>.delayed(Duration.zero);
          }
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('a sessao interrompida nao chegou ao RepositorioSessoes');
    }

    test('acao nomeia o desfecho real da sessao, nao "encerrou"', () async {
      final app = await abrirApp();
      app.iniciarSessao();

      // Em teste o canal nao responde e o fallback e tela LIGADA, entao o
      // paused interrompe de verdade — que e o comportamento conservador.
      final evento = await capturarEvento(
        () => app.aoMudarCicloDeVida(AppLifecycleState.paused),
      );

      // O rotulo vem de StatusSessao, e nao de uma inferencia por
      // `emAndamento`. Desde que o resumed tambem encerra sessao (concluindo
      // a que passou do alvo com a tela apagada), inferir rotularia uma
      // conclusao como interrupcao.
      expect(evento, contains('ação: ${StatusSessao.interrompida.rotulo}'));

      // E o rotulo BATE com o que foi gravado: e essa correspondencia que
      // torna o log citavel.
      expect(app.ultimaSessao!.status, StatusSessao.interrompida);
      expect(evento, contains(app.ultimaSessao!.status.rotulo));

      await esperarSessaoGravada();
    });

    test('paused registra os dois valores crus da tela', () async {
      final app = await abrirApp();

      final evento = await capturarEvento(
        () => app.aoMudarCicloDeVida(AppLifecycleState.paused),
      );

      // Sem os valores crus nao da para ver, no S23, se houve corrida entre
      // o apagar da tela e o onPause.
      expect(evento, contains('isInteractive:'));
      expect(evento, contains('isKeyguardLocked:'));
      expect(evento, contains('ação: ignorado'));
      expect(evento, contains('sessão ativa: não'));
    });

    test('evento que nao decide nada nao consulta a tela', () async {
      final app = await abrirApp();

      final evento = await capturarEvento(
        () => app.aoMudarCicloDeVida(AppLifecycleState.inactive),
      );

      // Consultar o canal em todo evento custaria um salto para o Android
      // onde a resposta nao muda desfecho nenhum.
      expect(evento, isNot(contains('isInteractive:')));
    });
  });

  test('abertura a frio grava o registro do dia', () async {
    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 45);

    await abrirApp();

    final registro = repositorioHistorico.carregarDia(hoje);
    expect(registro, isNotNull);
    expect(registro!.minutosRedesSociais, 45);
    expect(registro.houveMedicao, isTrue);
    expect(registro.cumprido, isTrue);
    expect(registro.energiaFinal, RegrasEnergia.energiaInicial);
  });

  test('dia de 0 minuto é dia CUMPRIDO, não lacuna', () async {
    // O dia perfeito e o dia sem medição produzem os mesmos 0 minutos; o que
    // os separa é `houveMedicao`. A guarda de escrita compara com o registro
    // JÁ GRAVADO do dia, e não com a medição anterior — por isso a primeira
    // medição válida do dia cria o registro mesmo sem nada a relatar.
    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 0);

    final app = await abrirApp();

    final registro = repositorioHistorico.carregarDia(hoje);
    expect(registro, isNotNull, reason: '0 minuto ainda é uma medição válida');
    expect(registro!.houveMedicao, isTrue);
    expect(registro.cumprido, isTrue);
    expect(registro.ehLacuna, isFalse);
    expect(app.sequenciaAtual, 1);
  });

  test('reavaliar um dia de 0 minuto não regrava nem duplica', () async {
    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 0);
    final app = await abrirApp();

    await app.avaliarUso();
    await app.avaliarUso();

    // O registro existe uma vez só: criar na primeira medição e não regravar
    // depois são as duas metades da mesma regra.
    expect(repositorioHistorico.todos(), hasLength(1));
    expect(repositorioHistorico.carregarDia(hoje)!.cumprido, isTrue);
  });

  test('sem permissão o dia entra como LACUNA, não como dia cumprido',
      () async {
    medicao = const MedicaoUso.semPermissao();

    await abrirApp();

    final registro = repositorioHistorico.carregarDia(hoje)!;
    expect(registro.ehLacuna, isTrue);
    expect(registro.cumprido, isFalse);
    expect(registro.falhou, isFalse);
    // Zero minuto sem medição não pode virar um dia perfeito.
    expect(registro.minutosRedesSociais, 0);
  });

  test('uso acima do limite grava o dia como falhado', () async {
    medicao = MedicaoUso(
      permissaoConcedida: true,
      minutos: RegrasEnergia.limiteDiarioRedesSociaisMinutos + 1,
    );

    await abrirApp();

    expect(repositorioHistorico.carregarDia(hoje)!.falhou, isTrue);
  });

  test('conta só as sessões do dia corrente', () async {
    await repositorioSessoes.adicionar(sessao(StatusSessao.concluida, hoje));
    await repositorioSessoes.adicionar(sessao(StatusSessao.concluida, hoje));
    await repositorioSessoes.adicionar(
      sessao(StatusSessao.interrompida, hoje),
    );
    // Ontem não entra na conta de hoje.
    await repositorioSessoes.adicionar(sessao(StatusSessao.concluida, ontem));

    await abrirApp();

    final registro = repositorioHistorico.carregarDia(hoje)!;
    expect(registro.sessoesConcluidas, 2);
    expect(registro.sessoesInterrompidas, 1);
  });

  test('reavaliar sem dado novo não cria uma segunda entrada', () async {
    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 30);
    final app = await abrirApp();

    // Três retornos ao primeiro plano sem uso novo.
    await app.avaliarUso();
    await app.avaliarUso();
    await app.avaliarUso();

    final todos = repositorioHistorico.todos();
    expect(todos, hasLength(1));
    expect(todos.single.minutosRedesSociais, 30);
  });

  test('uso novo entre avaliações atualiza o registro do mesmo dia', () async {
    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 30);
    final app = await abrirApp();

    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 90);
    await app.avaliarUso();

    final todos = repositorioHistorico.todos();
    expect(todos, hasLength(1));
    expect(todos.single.minutosRedesSociais, 90);
  });

  group('getters de sequência', () {
    test('primeiro dia de uso: sequência 1 assim que o dia é gravado',
        () async {
      medicao = const MedicaoUso(permissaoConcedida: true, minutos: 10);

      final app = await abrirApp();

      expect(app.sequenciaAtual, 1);
      expect(app.maiorSequencia, 1);
      expect(app.ultimos30Dias, hasLength(1));
    });

    test('dia corrente acima do limite zera a sequência', () async {
      medicao = MedicaoUso(
        permissaoConcedida: true,
        minutos: RegrasEnergia.limiteDiarioRedesSociaisMinutos + 60,
      );

      final app = await abrirApp();

      expect(app.sequenciaAtual, 0);
      expect(app.maiorSequencia, 0);
    });

    test('sequência atravessa uma lacuna gravada em dia anterior', () async {
      // Semeia dois dias bons e uma lacuna no meio, como se o app já
      // estivesse em uso há alguns dias.
      await repositorioHistorico.salvar(
        diaCumprido(DateTime(2026, 9, 17)),
      );
      await repositorioHistorico.salvar(
        diaLacuna(DateTime(2026, 9, 18)),
      );
      await repositorioHistorico.salvar(
        diaCumprido(DateTime(2026, 9, 19)),
      );

      medicao = const MedicaoUso(permissaoConcedida: true, minutos: 10);
      final app = await abrirApp();

      // 17, 19 e 20 contam; o 18 atravessa.
      expect(app.sequenciaAtual, 3);
      expect(app.ultimos30Dias, hasLength(4));
    });

    test('ultimos30Dias sai em ordem cronológica', () async {
      await repositorioHistorico.salvar(
        diaCumprido(DateTime(2026, 9, 18)),
      );
      await repositorioHistorico.salvar(
        diaCumprido(DateTime(2026, 9, 19)),
      );

      final app = await abrirApp();

      expect(
        app.ultimos30Dias.map((r) => r.dia).toList(),
        [
          DateTime(2026, 9, 18),
          DateTime(2026, 9, 19),
          DateTime(2026, 9, 20),
        ],
      );
    });
  });
}
