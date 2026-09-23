import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dados/repositorio_historico.dart';
import 'package:habitos_digitais/dados/repositorio_mascote.dart';
import 'package:habitos_digitais/dados/repositorio_sessoes.dart';
import 'package:habitos_digitais/dados/repositorio_uso.dart';
import 'package:habitos_digitais/dominio/regras_energia.dart';
import 'package:habitos_digitais/dominio/registro_diario.dart';
import 'package:habitos_digitais/estado/estado_mascote.dart';
import 'package:habitos_digitais/ui/tela_sequencia.dart';
import 'package:habitos_digitais/uso/medicao_uso.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

/// RF07, aba Sequência. Os números vêm prontos do EstadoApp — o que se
/// verifica aqui é que a tela os exibe, não que os calcula.
void main() {
  late Directory diretorio;
  late RepositorioMascote repositorioMascote;
  late RepositorioSessoes repositorioSessoes;
  late RepositorioUso repositorioUso;
  late RepositorioHistorico repositorioHistorico;
  EstadoApp? estado;

  final hoje = DateTime(2026, 9, 20, 15);

  setUp(() async {
    diretorio = await Directory.systemTemp.createTemp('habitos_seq_test');
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

  RegistroDiario dia(int atras, {required int minutos, bool mediu = true}) {
    return RegistroDiario(
      dia: DateTime(2026, 9, 20 - atras),
      minutosRedesSociais: minutos,
      sessoesConcluidas: 0,
      sessoesInterrompidas: 0,
      energiaFinal: 60,
      houveMedicao: mediu,
    );
  }

  final dentro = RegrasEnergia.limiteDiarioRedesSociaisMinutos - 1;
  final acima = RegrasEnergia.limiteDiarioRedesSociaisMinutos + 1;

  /// [medirUso] injetado para o teste poder escolher entre uma medicao que
  /// chega e uma que nunca chega.
  EstadoApp criar({Future<MedicaoUso> Function()? medirUso}) {
    final novo = EstadoApp(
      repositorioMascote: repositorioMascote,
      repositorioSessoes: repositorioSessoes,
      repositorioUso: repositorioUso,
      repositorioHistorico: repositorioHistorico,
      medirUso: medirUso ??
          () async => MedicaoUso(permissaoConcedida: true, minutos: dentro),
      relogio: () => hoje,
      agendarAberturaAFrio: (acao) => acao(),
    );
    estado = novo;
    return novo;
  }

  Widget montar() => ChangeNotifierProvider<EstadoApp>.value(
        value: estado!,
        child: const MaterialApp(home: Scaffold(body: TelaSequencia())),
      );

  /// Semeia o histórico e deixa o gatilho de abertura a frio assentar, como
  /// em `main.dart`: o EstadoApp nasce fora da zona fake-async porque grava
  /// em disco.
  Future<void> montarCom(
    WidgetTester tester,
    List<RegistroDiario> registros,
  ) async {
    await tester.runAsync(() async {
      for (final registro in registros) {
        await repositorioHistorico.salvar(registro);
      }
      await criar().primeiraAvaliacao;
    });
    await tester.pumpWidget(montar());
    await tester.pump();
  }

  testWidgets('primeiro uso nao parece erro: convida em vez de zerar',
      (tester) async {
    // Medicao que NUNCA chega: reproduz a janela real entre abrir o app e a
    // primeira leitura do UsageStatsManager voltar. Nesse intervalo nao ha
    // registro nenhum, nem o de hoje — e nenhuma escrita em disco fica
    // pendente para travar o tearDown.
    criar(medirUso: () => Completer<MedicaoUso>().future);
    await tester.pumpWidget(montar());
    await tester.pump();

    expect(find.text('Sua sequência começa hoje'), findsOneWidget);
    expect(
      find.text('Cada dia dentro do limite de uso entra na conta.'),
      findsOneWidget,
    );
    // Sem "0" em destaque: zero no primeiro dia leria como fracasso.
    expect(find.text('0'), findsNothing);
  });

  testWidgets('mostra sequencia atual e recorde vindos do EstadoApp',
      (tester) async {
    // Quebra em hoje-3: recorde 4 (hoje-7..hoje-4), atual 3 (hoje-2..hoje).
    await montarCom(tester, [
      for (var d = 7; d >= 4; d--) dia(d, minutos: dentro),
      dia(3, minutos: acima),
      for (var d = 2; d >= 1; d--) dia(d, minutos: dentro),
    ]);

    expect(estado!.sequenciaAtual, 3);
    expect(estado!.maiorSequencia, 4);

    expect(find.text('3'), findsOneWidget);
    expect(find.text('dias seguidos'), findsOneWidget);
    expect(find.text('Recorde'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('lacuna nao quebra a sequencia exibida', (tester) async {
    await montarCom(tester, [
      for (var d = 4; d >= 3; d--) dia(d, minutos: dentro),
      dia(2, minutos: 0, mediu: false),
      dia(1, minutos: dentro),
    ]);

    // hoje-4, hoje-3, hoje-1 e hoje contam; hoje-2 atravessa.
    expect(estado!.sequenciaAtual, 4);
    expect(estado!.maiorSequencia, 4);
    // Duas ocorrencias porque a sequencia em curso E o recorde valem 4 —
    // e a maior de todas e justamente a que atravessou a lacuna.
    expect(find.text('4'), findsNWidgets(2));
    expect(find.text('dias seguidos'), findsOneWidget);
  });

  testWidgets('a grade tem uma celula por dia dos ultimos 30',
      (tester) async {
    await montarCom(tester, [dia(1, minutos: dentro)]);

    expect(estado!.gradeUltimos30Dias, hasLength(30));
    expect(find.byType(Tooltip), findsNWidgets(30));
  });

  testWidgets('a legenda nomeia as tres categorias', (tester) async {
    await montarCom(tester, [dia(1, minutos: dentro)]);

    expect(find.text('Dentro do limite'), findsOneWidget);
    expect(find.text('Acima do limite'), findsOneWidget);
    expect(find.text('Sem medição'), findsOneWidget);
  });

  testWidgets('o historico de sessoes segue na base da aba', (tester) async {
    await montarCom(tester, [dia(1, minutos: dentro)]);

    expect(find.text('Nenhuma sessão registrada ainda.'), findsOneWidget);
  });

  testWidgets('singular quando a sequencia e de um dia', (tester) async {
    // Sem passado: so o registro de hoje, gravado pela primeira avaliacao.
    await montarCom(tester, const []);

    expect(estado!.sequenciaAtual, 1);
    expect(find.text('dia seguido'), findsOneWidget);
    expect(find.text('dias seguidos'), findsNothing);
  });
}
