import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dados/repositorio_mascote.dart';
import 'package:habitos_digitais/dados/repositorio_sessoes.dart';
import 'package:habitos_digitais/dominio/mascote.dart';
import 'package:habitos_digitais/dominio/sessao_foco.dart';
import 'package:hive/hive.dart';

/// Round-trip real de Hive num diretorio temporario.
///
/// Usa `Hive.init` (nao `initFlutter`) porque nao ha plugin/path_provider
/// disponivel no ambiente de teste. E a evidencia de que a persistencia do
/// RF01 funciona de fato, e nao so em memoria.
void main() {
  late Directory diretorio;

  setUp(() async {
    diretorio = await Directory.systemTemp.createTemp('habitos_hive_test');
    Hive.init(diretorio.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (diretorio.existsSync()) {
      diretorio.deleteSync(recursive: true);
    }
  });

  SessaoFoco sessao(StatusSessao status, DateTime inicio) => SessaoFoco(
        duracaoAlvo: const Duration(minutes: 25),
        duracaoReal: const Duration(minutes: 12, seconds: 34),
        inicioEm: inicio,
        status: status,
      );

  group('RepositorioMascote', () {
    Future<RepositorioMascote> abrir() async {
      final caixa = await Hive.openBox<int>(RepositorioMascote.nomeCaixa);
      return RepositorioMascote(caixa);
    }

    test('caixa vazia devolve o mascote inicial (50/Neutro)', () async {
      final repositorio = await abrir();

      final mascote = repositorio.carregar();
      expect(mascote.energia, 50);
      expect(mascote.estado, EstadoMascote.neutro);
    });

    test('energia sobrevive ao fechar e reabrir a caixa', () async {
      final repositorio = await abrir();
      await repositorio.salvar(Mascote(energia: 80));

      // Simula o app sendo fechado e reaberto.
      await Hive.close();
      final reaberto = await abrir();

      final mascote = reaberto.carregar();
      expect(mascote.energia, 80);
      expect(mascote.estado, EstadoMascote.feliz);
    });

    test('energia fora de faixa gravada na caixa e clampada ao carregar',
        () async {
      final caixa = await Hive.openBox<int>(RepositorioMascote.nomeCaixa);
      await caixa.put('energia', 999);

      expect(RepositorioMascote(caixa).carregar().energia, 100);
    });
  });

  group('RepositorioSessoes', () {
    Future<RepositorioSessoes> abrir() async {
      final caixa = await Hive.openBox<Map<dynamic, dynamic>>(
        RepositorioSessoes.nomeCaixa,
      );
      return RepositorioSessoes(caixa);
    }

    test('caixa vazia devolve lista vazia', () async {
      final repositorio = await abrir();

      expect(repositorio.todas(), isEmpty);
    });

    test('sessao sobrevive ao round-trip com todos os campos', () async {
      final repositorio = await abrir();
      final original = sessao(
        StatusSessao.interrompida,
        DateTime(2026, 9, 7, 14, 30, 45),
      );

      await repositorio.adicionar(original);
      await Hive.close();
      final reaberto = await abrir();

      final lidas = reaberto.todas();
      expect(lidas, hasLength(1));
      expect(lidas.single.duracaoAlvo, original.duracaoAlvo);
      expect(lidas.single.duracaoReal, original.duracaoReal);
      expect(lidas.single.inicioEm, original.inicioEm);
      expect(lidas.single.status, StatusSessao.interrompida);
    });

    test('todas() devolve da mais recente para a mais antiga', () async {
      final repositorio = await abrir();

      await repositorio.adicionar(
        sessao(StatusSessao.concluida, DateTime(2026, 9, 5)),
      );
      await repositorio.adicionar(
        sessao(StatusSessao.interrompida, DateTime(2026, 9, 6)),
      );
      await repositorio.adicionar(
        sessao(StatusSessao.concluida, DateTime(2026, 9, 7)),
      );

      expect(
        repositorio.todas().map((s) => s.inicioEm.day),
        [7, 6, 5],
      );
    });

    test('registro ilegivel e pulado sem derrubar o historico bom', () async {
      final caixa = await Hive.openBox<Map<dynamic, dynamic>>(
        RepositorioSessoes.nomeCaixa,
      );
      final repositorio = RepositorioSessoes(caixa);

      await repositorio.adicionar(
        sessao(StatusSessao.concluida, DateTime(2026, 9, 5)),
      );
      // Formato antigo/corrompido no meio da caixa.
      await caixa.add({'status': 'estado_que_nao_existe_mais'});
      await repositorio.adicionar(
        sessao(StatusSessao.concluida, DateTime(2026, 9, 7)),
      );

      final lidas = repositorio.todas();
      expect(lidas, hasLength(2));
      expect(lidas.map((s) => s.inicioEm.day), [7, 5]);
    });
  });
}
