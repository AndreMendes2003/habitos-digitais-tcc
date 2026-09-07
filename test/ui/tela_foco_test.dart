import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dados/repositorio_mascote.dart';
import 'package:habitos_digitais/dados/repositorio_sessoes.dart';
import 'package:habitos_digitais/dominio/sessao_foco.dart';
import 'package:habitos_digitais/ui/tela_foco.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory diretorio;
  late RepositorioMascote repositorioMascote;
  late RepositorioSessoes repositorioSessoes;

  setUp(() async {
    diretorio = await Directory.systemTemp.createTemp('habitos_tela_test');
    Hive.init(diretorio.path);
    repositorioMascote = RepositorioMascote(
      await Hive.openBox<int>(RepositorioMascote.nomeCaixa),
    );
    repositorioSessoes = RepositorioSessoes(
      await Hive.openBox<Map<dynamic, dynamic>>(RepositorioSessoes.nomeCaixa),
    );
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
        ),
      );

  /// Emite os estados de ciclo de vida percorrendo o caminho real do Android.
  ///
  /// O `paused` dispara `aoFinalizarSessao`, que grava no Hive. Escrita de
  /// disco de verdade NAO completa dentro da zona fake-async do `testWidgets`
  /// — o teste travaria esperando um IO que a zona nunca bombeia. Por isso
  /// essa transicao vai dentro de `runAsync`, a unica forma de deixar async
  /// real rodar num teste de widget.
  Future<void> emitirCicloDeVida(
    WidgetTester tester,
    List<AppLifecycleState> estados,
  ) async {
    for (final estado in estados) {
      if (estado == AppLifecycleState.paused) {
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
    await tester.pumpWidget(montar());

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
    await tester.pumpWidget(montar());

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
    await tester.pumpWidget(montar());
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
        repositorioMascote.carregar().aplicar(anterior),
      );
      await repositorioSessoes.adicionar(anterior);
    });

    await tester.pumpWidget(montar());

    expect(find.text('Energia: 65/100'), findsOneWidget);
    expect(find.text('Neutro'), findsOneWidget);
    expect(find.text('25 min — CONCLUÍDA'), findsOneWidget);
  });
}
