import 'dart:io';

import 'package:flutter/foundation.dart';
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
