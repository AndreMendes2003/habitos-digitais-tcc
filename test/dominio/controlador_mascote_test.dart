import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dominio/controlador_mascote.dart';
import 'package:habitos_digitais/dominio/mascote.dart';
import 'package:habitos_digitais/dominio/sessao_foco.dart';

void main() {
  SessaoFoco sessao(StatusSessao status) => SessaoFoco(
        duracaoAlvo: const Duration(minutes: 5),
        duracaoReal: const Duration(minutes: 5),
        inicioEm: DateTime(2026, 9, 7, 10),
        status: status,
      );

  test('sem mascote inicial, comeca no padrao (50/Neutro)', () {
    final controlador = ControladorMascote();
    addTearDown(controlador.dispose);

    expect(controlador.mascote.energia, 50);
    expect(controlador.mascote.estado, EstadoMascote.neutro);
  });

  test('registrar sessao concluida aplica o delta e notifica', () async {
    final controlador = ControladorMascote(inicial: Mascote(energia: 50));
    addTearDown(controlador.dispose);

    var notificacoes = 0;
    controlador.addListener(() => notificacoes++);

    await controlador.registrarSessao(sessao(StatusSessao.concluida));

    expect(controlador.mascote.energia, 65);
    expect(notificacoes, 1);
  });

  test('registrar sessao interrompida aplica o delta negativo', () async {
    final controlador = ControladorMascote(inicial: Mascote(energia: 50));
    addTearDown(controlador.dispose);

    await controlador.registrarSessao(sessao(StatusSessao.interrompida));

    expect(controlador.mascote.energia, 40);
  });

  test('cada sessao dispara a persistencia com o mascote ja atualizado', () async {
    final persistidos = <Mascote>[];
    final controlador = ControladorMascote(
      inicial: Mascote(energia: 50),
      aoPersistir: (m) async => persistidos.add(m),
    );
    addTearDown(controlador.dispose);

    await controlador.registrarSessao(sessao(StatusSessao.concluida));
    await controlador.registrarSessao(sessao(StatusSessao.interrompida));

    expect(persistidos.map((m) => m.energia), [65, 55]);
  });

  test('sessoes acumulam e respeitam o clamp', () async {
    final controlador = ControladorMascote(inicial: Mascote(energia: 90));
    addTearDown(controlador.dispose);

    await controlador.registrarSessao(sessao(StatusSessao.concluida));
    await controlador.registrarSessao(sessao(StatusSessao.concluida));

    expect(controlador.mascote.energia, 100);
  });
}
