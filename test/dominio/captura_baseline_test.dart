import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dados/repositorio_baseline.dart';
import 'package:habitos_digitais/dados/repositorio_historico.dart';
import 'package:habitos_digitais/dominio/calculo_sequencia.dart';
import 'package:habitos_digitais/dominio/captura_baseline.dart';
import 'package:habitos_digitais/dominio/regras_energia.dart';
import 'package:habitos_digitais/dominio/registro_diario.dart';
import 'package:habitos_digitais/uso/medicao_uso.dart';
import 'package:hive/hive.dart';

/// Captura retroativa da linha de base: os dias anteriores à instalação.
void main() {
  late Directory diretorio;
  late RepositorioHistorico repositorioHistorico;
  late RepositorioBaseline repositorioBaseline;

  final hoje = DateTime(2026, 9, 20, 15);

  /// Dias consultados, na ordem, para verificar a janela varrida.
  late List<DateTime> consultados;

  setUp(() async {
    diretorio = await Directory.systemTemp.createTemp('habitos_base_test');
    Hive.init(diretorio.path);
    repositorioHistorico = RepositorioHistorico(
      await Hive.openBox<Map<dynamic, dynamic>>(
        RepositorioHistorico.nomeCaixa,
      ),
    );
    repositorioBaseline = RepositorioBaseline(
      await Hive.openBox<Map<dynamic, dynamic>>(
        RepositorioBaseline.nomeCaixa,
      ),
    );
    consultados = [];
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (diretorio.existsSync()) {
      diretorio.deleteSync(recursive: true);
    }
  });

  CapturaBaseline capturaQue(
    Future<MedicaoUso> Function(DateTime dia) medir,
  ) {
    return CapturaBaseline(
      medirDia: (dia) {
        consultados.add(dia);
        return medir(dia);
      },
      repositorioHistorico: repositorioHistorico,
      repositorioBaseline: repositorioBaseline,
    );
  }

  Future<MedicaoUso> comMinutos(int minutos) async =>
      MedicaoUso(permissaoConcedida: true, minutos: minutos);

  test('varre os 7 dias anteriores, sem incluir hoje', () async {
    final capturados =
        await capturaQue((_) => comMinutos(40)).capturarSeNecessario(hoje);

    expect(capturados, 7);
    expect(consultados, hasLength(7));
    // Do mais antigo para o mais recente, e hoje fica de fora: o dia corrente
    // e do periodo de intervencao e ja e gravado pelo fluxo do RF04.
    expect(consultados.first, DateTime(2026, 9, 13));
    expect(consultados.last, DateTime(2026, 9, 19));
    expect(
      consultados.any((d) => d == DateTime(2026, 9, 20)),
      isFalse,
      reason: 'hoje nao pode ser capturado como baseline',
    );
  });

  test('grava como RegistroDiario marcado, com o limite vigente', () async {
    await capturaQue((_) => comMinutos(40)).capturarSeNecessario(hoje);

    final registro = repositorioHistorico.carregarDia(DateTime(2026, 9, 19))!;

    expect(registro.ehBaseline, isTrue);
    expect(registro.minutosRedesSociais, 40);
    expect(registro.houveMedicao, isTrue);
    expect(registro.cumprido, isTrue);
    expect(
      registro.limiteDiarioMinutos,
      RegrasEnergia.limiteDiarioRedesSociaisMinutos,
    );
    // O app nao existia nesses dias.
    expect(registro.sessoesConcluidas, 0);
    expect(registro.sessoesInterrompidas, 0);
  });

  test('a classificação real do dia é preservada', () async {
    // Um dia acima do limite tem de constar como acima: e esse o dado da
    // linha de base.
    await capturaQue((dia) async {
      final estourou = dia == DateTime(2026, 9, 17);
      return comMinutos(
        estourou ? RegrasEnergia.limiteDiarioRedesSociaisMinutos + 100 : 30,
      );
    }).capturarSeNecessario(hoje);

    expect(
      repositorioHistorico.carregarDia(DateTime(2026, 9, 17))!.falhou,
      isTrue,
    );
    expect(
      repositorioHistorico.carregarDia(DateTime(2026, 9, 16))!.cumprido,
      isTrue,
    );
  });

  test('dia sem dado vira LACUNA, não zero', () async {
    await capturaQue((dia) async {
      if (dia == DateTime(2026, 9, 15)) {
        // Sistema sem dado dessa janela: minutos 0, mas nao ha medicao.
        return const MedicaoUso(
          permissaoConcedida: true,
          minutos: 0,
          houveDados: false,
        );
      }
      // Zero legitimo: houve dado, nenhum app da lista foi usado.
      return const MedicaoUso(permissaoConcedida: true, minutos: 0);
    }).capturarSeNecessario(hoje);

    final semDado = repositorioHistorico.carregarDia(DateTime(2026, 9, 15))!;
    expect(semDado.ehLacuna, isTrue);
    expect(semDado.cumprido, isFalse);

    final zeroReal = repositorioHistorico.carregarDia(DateTime(2026, 9, 14))!;
    expect(zeroReal.ehLacuna, isFalse);
    expect(zeroReal.cumprido, isTrue);
  });

  test('um dia que estoura não aborta a varredura dos outros', () async {
    await capturaQue((dia) async {
      if (dia == DateTime(2026, 9, 16)) throw StateError('falha de plugin');
      return comMinutos(30);
    }).capturarSeNecessario(hoje);

    expect(repositorioHistorico.todos(), hasLength(7));
    expect(
      repositorioHistorico.carregarDia(DateTime(2026, 9, 16))!.ehLacuna,
      isTrue,
    );
    expect(
      repositorioHistorico.carregarDia(DateTime(2026, 9, 15))!.cumprido,
      isTrue,
    );
  });

  group('acontece uma vez só', () {
    test('a segunda chamada não captura nada', () async {
      final captura = capturaQue((_) => comMinutos(40));

      expect(await captura.capturarSeNecessario(hoje), 7);
      expect(repositorioBaseline.jaCapturado, isTrue);

      consultados.clear();
      expect(await captura.capturarSeNecessario(hoje), 0);
      expect(consultados, isEmpty, reason: 'nao pode nem consultar de novo');
    });

    test('não sobrescreve dias já vividos com o app', () async {
      // Dia de intervencao ja gravado, dentro da janela retroativa.
      await repositorioHistorico.salvar(
        RegistroDiario(
          dia: DateTime(2026, 9, 18),
          minutosRedesSociais: 200,
          sessoesConcluidas: 3,
          sessoesInterrompidas: 1,
          energiaFinal: 80,
          houveMedicao: true,
        ),
      );
      await repositorioBaseline.marcar(DateTime(2026, 9, 18), 7);

      await capturaQue((_) => comMinutos(10)).capturarSeNecessario(hoje);

      final preservado =
          repositorioHistorico.carregarDia(DateTime(2026, 9, 18))!;
      expect(preservado.ehBaseline, isFalse);
      expect(preservado.minutosRedesSociais, 200);
      expect(preservado.sessoesConcluidas, 3);
    });
  });

  group('efeito na sequência', () {
    test('7 dias de baseline NÃO viram sequência de 7', () async {
      await capturaQue((_) => comMinutos(30)).capturarSeNecessario(hoje);

      // Dia corrente, ja de intervencao.
      await repositorioHistorico.salvar(
        RegistroDiario(
          dia: hoje,
          minutosRedesSociais: 30,
          sessoesConcluidas: 0,
          sessoesInterrompidas: 0,
          energiaFinal: 50,
          houveMedicao: true,
        ),
      );

      final registros = repositorioHistorico.todos();

      // O usuario construiu UM dia, nao oito.
      expect(CalculoSequencia.atual(registros, hoje), 1);
      expect(CalculoSequencia.maior(registros, hoje), 1);
    });

    test('baseline acima do limite também não quebra nada', () async {
      await capturaQue(
        (_) => comMinutos(RegrasEnergia.limiteDiarioRedesSociaisMinutos + 200),
      ).capturarSeNecessario(hoje);

      await repositorioHistorico.salvar(
        RegistroDiario(
          dia: hoje,
          minutosRedesSociais: 30,
          sessoesConcluidas: 0,
          sessoesInterrompidas: 0,
          energiaFinal: 50,
          houveMedicao: true,
        ),
      );

      final registros = repositorioHistorico.todos();

      // Atravessa nas duas direcoes: nem soma nem zera.
      expect(CalculoSequencia.atual(registros, hoje), 1);
      expect(registros.first.falhou, isTrue, reason: 'o dado segue real');
    });
  });
}
