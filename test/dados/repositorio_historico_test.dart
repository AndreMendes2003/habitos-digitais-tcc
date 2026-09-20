import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dados/repositorio_historico.dart';
import 'package:habitos_digitais/dominio/registro_diario.dart';
import 'package:hive/hive.dart';

/// Round-trip real de Hive, mesmo padrão de `repositorios_test.dart`:
/// `Hive.init` num diretório temporário, sem plugin.
void main() {
  late Directory diretorio;

  setUp(() async {
    diretorio = await Directory.systemTemp.createTemp('habitos_hist_test');
    Hive.init(diretorio.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (diretorio.existsSync()) {
      diretorio.deleteSync(recursive: true);
    }
  });

  Future<RepositorioHistorico> abrir() async {
    final caixa = await Hive.openBox<Map<dynamic, dynamic>>(
      RepositorioHistorico.nomeCaixa,
    );
    return RepositorioHistorico(caixa);
  }

  RegistroDiario registro(
    DateTime dia, {
    int minutos = 30,
    bool houveMedicao = true,
    int concluidas = 2,
    int interrompidas = 1,
    int energia = 65,
  }) {
    return RegistroDiario(
      dia: dia,
      minutosRedesSociais: minutos,
      sessoesConcluidas: concluidas,
      sessoesInterrompidas: interrompidas,
      energiaFinal: energia,
      houveMedicao: houveMedicao,
    );
  }

  test('dia sem registro devolve null, e não um registro zerado', () async {
    final repositorio = await abrir();

    // O null é o que o cálculo de sequência lê como lacuna.
    expect(repositorio.carregarDia(DateTime(2026, 9, 20)), isNull);
    expect(repositorio.todos(), isEmpty);
  });

  test('registro sobrevive ao fechar e reabrir a caixa', () async {
    final repositorio = await abrir();
    await repositorio.salvar(
      registro(
        DateTime(2026, 9, 20, 14, 33),
        minutos: 95,
        concluidas: 3,
        interrompidas: 2,
        energia: 72,
      ),
    );

    await Hive.close();
    final reaberto = await abrir();
    final lido = reaberto.carregarDia(DateTime(2026, 9, 20));

    expect(lido, isNotNull);
    // A hora é descartada: a chave é a data.
    expect(lido!.dia, DateTime(2026, 9, 20));
    expect(lido.minutosRedesSociais, 95);
    expect(lido.sessoesConcluidas, 3);
    expect(lido.sessoesInterrompidas, 2);
    expect(lido.energiaFinal, 72);
    expect(lido.houveMedicao, isTrue);
  });

  test('regravar o mesmo dia atualiza em vez de duplicar', () async {
    final repositorio = await abrir();
    final dia = DateTime(2026, 9, 20);

    // É o caso normal: o dia corrente é reescrito a cada avaliação de uso.
    await repositorio.salvar(registro(dia, minutos: 10));
    await repositorio.salvar(registro(dia, minutos: 40));
    await repositorio.salvar(registro(dia, minutos: 130));

    final todos = repositorio.todos();
    expect(todos, hasLength(1));
    expect(todos.single.minutosRedesSociais, 130);
    expect(todos.single.cumprido, isFalse);
  });

  test('hora do dia não cria uma segunda entrada', () async {
    final repositorio = await abrir();

    await repositorio.salvar(registro(DateTime(2026, 9, 20, 8), minutos: 20));
    await repositorio.salvar(registro(DateTime(2026, 9, 20, 23), minutos: 60));

    expect(repositorio.todos(), hasLength(1));
    expect(repositorio.todos().single.minutosRedesSociais, 60);
  });

  test('todos() devolve em ordem cronológica', () async {
    final repositorio = await abrir();

    await repositorio.salvar(registro(DateTime(2026, 9, 18)));
    await repositorio.salvar(registro(DateTime(2026, 9, 20)));
    await repositorio.salvar(registro(DateTime(2026, 9, 19)));

    expect(
      repositorio.todos().map((r) => r.dia).toList(),
      [DateTime(2026, 9, 18), DateTime(2026, 9, 19), DateTime(2026, 9, 20)],
    );
  });

  test('lacuna persiste como lacuna', () async {
    final repositorio = await abrir();
    await repositorio.salvar(
      RegistroDiario.lacuna(DateTime(2026, 9, 20), energiaFinal: 44),
    );

    final lido = repositorio.carregarDia(DateTime(2026, 9, 20))!;

    expect(lido.ehLacuna, isTrue);
    expect(lido.cumprido, isFalse);
    expect(lido.falhou, isFalse);
    expect(lido.energiaFinal, 44);
  });

  test('registro ilegível é pulado sem derrubar o histórico bom', () async {
    final caixa = await Hive.openBox<Map<dynamic, dynamic>>(
      RepositorioHistorico.nomeCaixa,
    );
    final repositorio = RepositorioHistorico(caixa);

    await repositorio.salvar(registro(DateTime(2026, 9, 19)));
    // Formato anterior/corrompido: falta campo obrigatório.
    await caixa.put('2026-09-20', {'dia': '2026-09-20'});
    await repositorio.salvar(registro(DateTime(2026, 9, 21)));

    final todos = repositorio.todos();

    expect(todos, hasLength(2));
    expect(todos.map((r) => r.dia), [
      DateTime(2026, 9, 19),
      DateTime(2026, 9, 21),
    ]);
    expect(repositorio.carregarDia(DateTime(2026, 9, 20)), isNull);
  });
}
