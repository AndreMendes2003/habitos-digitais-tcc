import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dominio/avaliacao_uso.dart';
import 'package:habitos_digitais/dominio/controlador_uso.dart';
import 'package:habitos_digitais/uso/medicao_uso.dart';

/// RF04: idempotencia da penalidade por uso.
///
/// A medicao entra injetada, entao a regra inteira e testavel sem plugin e
/// sem MethodChannel.
void main() {
  late DateTime agora;
  late MedicaoUso proximaMedicao;
  late List<AvaliacaoUsoDiaria> persistidas;

  ControladorUso criar({AvaliacaoUsoDiaria? avaliacaoInicial}) {
    final c = ControladorUso(
      medir: () async => proximaMedicao,
      avaliacaoInicial: avaliacaoInicial,
      aoPersistir: (a) async => persistidas.add(a),
      relogio: () => agora,
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    agora = DateTime(2026, 9, 7, 14, 30);
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 0);
    persistidas = [];
  });

  test('abaixo do limite nao penaliza mas registra os minutos', () async {
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 90);
    final controlador = criar();

    expect(await controlador.avaliar(), 0);
    expect(controlador.minutosHoje, 90);
    expect(persistidas.single.minutosContabilizados, 90);
  });

  test('acima do limite penaliza o bloco completo', () async {
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 150);
    final controlador = criar();

    expect(await controlador.avaliar(), -5);
  });

  test('IDEMPOTENCIA: reavaliar no mesmo dia sem uso novo nao desconta', () async {
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 150);
    final controlador = criar();

    expect(await controlador.avaliar(), -5);
    // Usuario reabriu o app: mesma medicao, mesmo dia.
    expect(await controlador.avaliar(), 0);
    expect(await controlador.avaliar(), 0);
    expect(await controlador.avaliar(), 0);
  });

  test('IDEMPOTENCIA: uso novo desconta so o delta', () async {
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 150);
    final controlador = criar();
    expect(await controlador.avaliar(), -5);

    // Mais 30 min de rede social: fecha o segundo bloco.
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 180);
    expect(await controlador.avaliar(), -5); // -10 devido, -5 ja cobrado

    // Mais uso, mas sem fechar bloco novo.
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 200);
    expect(await controlador.avaliar(), 0);
  });

  test('IDEMPOTENCIA: teto respeitado mesmo em varias avaliacoes', () async {
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 300);
    final controlador = criar();
    expect(await controlador.avaliar(), -30);

    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 600);
    // Ja no teto: nao ha mais o que cobrar hoje.
    expect(await controlador.avaliar(), 0);
  });

  test('VIRADA DE DIA zera o contador e penaliza de novo', () async {
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 150);
    final controlador = criar();
    expect(await controlador.avaliar(), -5);
    expect(await controlador.avaliar(), 0);

    // Dia seguinte: o usage_stats volta a contar do zero, e a penalidade
    // acumulada do dia anterior nao pode abater a de hoje.
    agora = DateTime(2026, 9, 8, 9);
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 150);

    expect(await controlador.avaliar(), -5);
    expect(persistidas.last.dia, DateTime(2026, 9, 8));
  });

  test('estado persistido de ontem e descartado', () async {
    final ontem = AvaliacaoUsoDiaria(
      dia: DateTime(2026, 9, 6),
      minutosContabilizados: 300,
    );
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 150);
    final controlador = criar(avaliacaoInicial: ontem);

    // Se o contador de ontem contasse, -30 ja cobrado abateria tudo.
    expect(await controlador.avaliar(), -5);
  });

  test('PERMISSAO AUSENTE: nao penaliza, nao grava, sinaliza', () async {
    proximaMedicao = const MedicaoUso.semPermissao();
    final controlador = criar();

    expect(await controlador.avaliar(), 0);
    expect(controlador.permissaoConcedida, isFalse);
    expect(persistidas, isEmpty);
  });

  test('permissao concedida depois volta a medir', () async {
    proximaMedicao = const MedicaoUso.semPermissao();
    final controlador = criar();
    await controlador.avaliar();
    expect(controlador.permissaoConcedida, isFalse);

    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 150);
    expect(await controlador.avaliar(), -5);
    expect(controlador.permissaoConcedida, isTrue);
  });

  test('minutos caindo nunca devolve energia', () async {
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 300);
    final controlador = criar();
    expect(await controlador.avaliar(), -30);

    // Relogio do device ajustado para tras, por exemplo.
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 10);
    expect(await controlador.avaliar(), 0);
    // E o ja cobrado nao regride, senao o proximo uso cobraria em dobro.
    expect(persistidas.last.minutosContabilizados, 300);
  });

  test('avaliacoes concorrentes nao cobram duas vezes', () async {
    proximaMedicao = const MedicaoUso(permissaoConcedida: true, minutos: 150);
    final controlador = criar();

    // Resume e fim de sessao disparando juntos.
    final resultados = await Future.wait([
      controlador.avaliar(),
      controlador.avaliar(),
    ]);

    expect(resultados.reduce((a, b) => a + b), -5);
  });
}
