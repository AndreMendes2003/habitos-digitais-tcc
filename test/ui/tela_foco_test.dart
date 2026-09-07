import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dados/repositorio_mascote.dart';
import 'package:habitos_digitais/dados/repositorio_sessoes.dart';
import 'package:habitos_digitais/dados/repositorio_uso.dart';
import 'package:habitos_digitais/dominio/avaliacao_uso.dart';
import 'package:habitos_digitais/dominio/mascote.dart';
import 'package:habitos_digitais/dominio/regras_energia.dart';
import 'package:habitos_digitais/dominio/sessao_foco.dart';
import 'package:habitos_digitais/ui/tela_foco.dart';
import 'package:habitos_digitais/uso/medicao_uso.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory diretorio;
  late RepositorioMascote repositorioMascote;
  late RepositorioSessoes repositorioSessoes;
  late RepositorioUso repositorioUso;

  /// Medição injetada: o widget test nunca toca no plugin usage_stats.
  late MedicaoUso medicao;

  setUp(() async {
    diretorio = await Directory.systemTemp.createTemp('habitos_tela_test');
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
    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 0);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (diretorio.existsSync()) {
      diretorio.deleteSync(recursive: true);
    }
  });

  Widget montar() => MaterialApp(
        home: TelaFoco(
          repositorioMascote: repositorioMascote,
          repositorioSessoes: repositorioSessoes,
          repositorioUso: repositorioUso,
          medirUso: () async => medicao,
        ),
      );

  /// Monta a tela e deixa a avaliação de uso do `initState` assentar.
  ///
  /// LIMITE DO HARNESS: `pumpWidget` roda na zona fake-async e não pode ser
  /// chamado dentro de `runAsync`. Uma escrita no Hive iniciada aí nunca
  /// completa, e o `Hive.deleteFromDisk()` do tearDown fica esperando por ela
  /// para sempre. Por isso os testes que exercitam a PENALIDADE fazem-na pelo
  /// `resumed` (que passa por `runAsync` em `emitirCicloDeVida`), e a abertura
  /// a frio é testada em cenários que não geram escrita nova.
  Future<void> montarEAssentar(WidgetTester tester) async {
    await tester.pumpWidget(montar());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  /// Emite os estados de ciclo de vida percorrendo o caminho real do Android.
  ///
  /// Dois estados gravam no Hive: `paused` dispara `aoFinalizarSessao` e
  /// `resumed` dispara a avaliacao de uso do RF04. Escrita de disco de verdade
  /// NAO completa dentro da zona fake-async do `testWidgets` — o teste
  /// travaria esperando um IO que a zona nunca bombeia. Por isso essas duas
  /// transicoes vao dentro de `runAsync`, a unica forma de deixar async real
  /// rodar num teste de widget.
  Future<void> emitirCicloDeVida(
    WidgetTester tester,
    List<AppLifecycleState> estados,
  ) async {
    const gravamNoDisco = {
      AppLifecycleState.paused,
      AppLifecycleState.resumed,
    };

    for (final estado in estados) {
      if (gravamNoDisco.contains(estado)) {
        await tester.runAsync(() async {
          tester.binding.handleAppLifecycleStateChanged(estado);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
      } else {
        tester.binding.handleAppLifecycleStateChanged(estado);
      }
      await tester.pump();
    }
  }

  testWidgets('mostra mascote, seletor de duracao e botao inicial',
      (tester) async {
    await montarEAssentar(tester);

    expect(find.text('Neutro'), findsOneWidget);
    expect(find.text('Energia: 50/100'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    expect(find.text('Iniciar foco'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
  });

  testWidgets('RNF01: so o paused encerra a sessao como INTERROMPIDA',
      (tester) async {
    await montarEAssentar(tester);

    await tester.tap(find.text('5 min'));
    await tester.pump();
    await tester.tap(find.text('Iniciar foco'));
    await tester.pump();

    expect(find.text('Em foco — não saia do app'), findsOneWidget);

    // Puxar a barra de notificacao emite `inactive` sem tirar o app do
    // primeiro plano: a sessao tem que sobreviver a isso.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Em foco — não saia do app'), findsOneWidget);
    expect(find.text('INTERROMPIDA'), findsNothing);

    // Saida de verdade. De `hidden` em diante o binding desabilita frames
    // (SchedulerBinding._setFramesEnabledState), entao a arvore so repinta
    // quando o app volta — que e tambem o que acontece no device: o usuario
    // retorna e ai ve o resultado. Por isso as assercoes vem depois do
    // caminho de volta ate `resumed`.
    // O `paused` cancela o Timer da sessao, entao nao sobra timer pendente.
    await emitirCicloDeVida(tester, [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    expect(find.text('INTERROMPIDA'), findsWidgets);
    expect(find.text('Nova sessão'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Início: \d{2}/\d{2}/\d{4} \d{2}:\d{2}$')),
      findsOneWidget,
    );
  });

  testWidgets('RF04: sessao interrompida desconta energia e persiste tudo',
      (tester) async {
    await montarEAssentar(tester);
    expect(find.text('Energia: 50/100'), findsOneWidget);

    await tester.tap(find.text('5 min'));
    await tester.pump();
    await tester.tap(find.text('Iniciar foco'));
    await tester.pump();

    await emitirCicloDeVida(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    // A tela reflete a energia nova...
    expect(find.text('Energia: 40/100'), findsOneWidget);
    expect(find.text('Neutro'), findsOneWidget);

    // ...e o disco tambem, que e o ponto do RF01.
    expect(repositorioMascote.carregar().energia, 40);
    final salvas = repositorioSessoes.todas();
    expect(salvas, hasLength(1));
    expect(salvas.single.status, StatusSessao.interrompida);
  });

  testWidgets('mascote e historico salvos aparecem ao reabrir a tela',
      (tester) async {
    final anterior = SessaoFoco(
      duracaoAlvo: const Duration(minutes: 25),
      duracaoReal: const Duration(minutes: 25),
      inicioEm: DateTime(2026, 9, 6, 9),
      status: StatusSessao.concluida,
    );

    // Simula uma execucao anterior do app. Vai dentro de `runAsync` porque
    // gravacao real em disco nao completa na zona fake-async do testWidgets.
    await tester.runAsync(() async {
      await repositorioMascote.salvar(
        repositorioMascote.carregar().comDelta(
          RegrasEnergia.deltaParaSessao(anterior.status),
        ),
      );
      await repositorioSessoes.adicionar(anterior);
    });

    await montarEAssentar(tester);

    expect(find.text('Energia: 65/100'), findsOneWidget);
    expect(find.text('Neutro'), findsOneWidget);
    expect(find.text('25 min — CONCLUÍDA'), findsOneWidget);
  });

  testWidgets('RF04: linha de status mostra minutos e limite', (tester) async {
    await montarEAssentar(tester);
    expect(find.text('Redes sociais hoje: 0 min / 120 min'), findsOneWidget);

    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 45);
    await emitirCicloDeVida(tester, [AppLifecycleState.resumed]);

    expect(find.text('Redes sociais hoje: 45 min / 120 min'), findsOneWidget);
    // Abaixo do limite: energia intocada.
    expect(find.text('Energia: 50/100'), findsOneWidget);
  });

  testWidgets('RF04: sem permissao sinaliza na UI e nao penaliza',
      (tester) async {
    medicao = const MedicaoUso.semPermissao();

    await montarEAssentar(tester);

    expect(
      find.text('Redes sociais hoje: permissão não concedida'),
      findsOneWidget,
    );
    expect(find.text('Energia: 50/100'), findsOneWidget);
    expect(repositorioMascote.carregar().energia, 50);
    expect(repositorioUso.carregar(), isNull);
  });

  testWidgets('RF04: uso acima do limite desconta ao voltar ao app',
      (tester) async {
    await montarEAssentar(tester);
    expect(find.text('Energia: 50/100'), findsOneWidget);

    // 300 min = 180 acima do limite = 6 blocos = teto de -30.
    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 300);
    await emitirCicloDeVida(tester, [AppLifecycleState.resumed]);

    expect(find.text('Redes sociais hoje: 300 min / 120 min'), findsOneWidget);
    expect(find.text('Energia: 20/100'), findsOneWidget);
    expect(find.text('Cansado'), findsOneWidget);
    expect(repositorioMascote.carregar().energia, 20);
  });

  testWidgets('RF04 IDEMPOTENCIA: voltar ao app nao desconta de novo',
      (tester) async {
    await montarEAssentar(tester);

    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 150);
    await emitirCicloDeVida(tester, [AppLifecycleState.resumed]);
    expect(find.text('Energia: 45/100'), findsOneWidget);

    // Usuario sai e volta tres vezes, sem uso novo de rede social.
    for (var i = 0; i < 3; i++) {
      await emitirCicloDeVida(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
    }

    expect(find.text('Energia: 45/100'), findsOneWidget);
    expect(repositorioMascote.carregar().energia, 45);
  });

  testWidgets('RF04 IDEMPOTENCIA: reabrir o app com uso ja cobrado nao desconta',
      (tester) async {
    // Simula uma execucao anterior que ja cobrou os 300 min de hoje.
    final hoje = DateTime.now();
    await tester.runAsync(() async {
      await repositorioUso.salvar(
        AvaliacaoUsoDiaria(
          dia: DateTime(hoje.year, hoje.month, hoje.day),
          minutosContabilizados: 300,
        ),
      );
      await repositorioMascote.salvar(Mascote(energia: 20));
    });
    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 300);

    // Abertura a frio: o gatilho do initState roda e NAO pode cobrar de novo.
    await montarEAssentar(tester);

    expect(find.text('Energia: 20/100'), findsOneWidget);
    expect(repositorioMascote.carregar().energia, 20);
  });

  testWidgets('RF04: uso novo entre resumes desconta so o delta',
      (tester) async {
    await montarEAssentar(tester);

    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 150);
    await emitirCicloDeVida(tester, [AppLifecycleState.resumed]);
    expect(find.text('Energia: 45/100'), findsOneWidget);

    // Enquanto fora do app, o usuario passou mais 30 min na rede social.
    medicao = const MedicaoUso(permissaoConcedida: true, minutos: 180);
    await emitirCicloDeVida(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    // Só o segundo bloco novo é cobrado: 45 - 5, não 45 - 10.
    expect(find.text('Energia: 40/100'), findsOneWidget);
    expect(find.text('Redes sociais hoje: 180 min / 120 min'), findsOneWidget);
  });
}
