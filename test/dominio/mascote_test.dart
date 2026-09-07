import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dominio/mascote.dart';
import 'package:habitos_digitais/dominio/regras_energia.dart';
import 'package:habitos_digitais/dominio/sessao_foco.dart';

/// FSM do RF01. Regra de negocio pura: nenhum widget, nenhum Hive.
///
/// Os limites usam numeros LITERAIS (29/30, 69/70) de proposito. Sao eles que
/// travam o requisito: se alguem mexer em RegrasEnergia, o teste quebra e a
/// mudanca vira uma decisao consciente em vez de um efeito colateral.
void main() {
  SessaoFoco sessao(StatusSessao status) => SessaoFoco(
        duracaoAlvo: const Duration(minutes: 25),
        duracaoReal: const Duration(minutes: 25),
        inicioEm: DateTime(2026, 9, 7, 10),
        status: status,
      );

  group('estado derivado da energia', () {
    test('mascote novo nasce com 50 e Neutro', () {
      final mascote = Mascote();

      expect(mascote.energia, 50);
      expect(mascote.estado, EstadoMascote.neutro);
    });

    test('limite Feliz: 69 e Neutro, 70 e Feliz', () {
      expect(Mascote(energia: 69).estado, EstadoMascote.neutro);
      expect(Mascote(energia: 70).estado, EstadoMascote.feliz);
    });

    test('limite Cansado: 29 e Cansado, 30 e Neutro', () {
      expect(Mascote(energia: 29).estado, EstadoMascote.cansado);
      expect(Mascote(energia: 30).estado, EstadoMascote.neutro);
    });

    test('extremos da faixa', () {
      expect(Mascote(energia: 0).estado, EstadoMascote.cansado);
      expect(Mascote(energia: 100).estado, EstadoMascote.feliz);
    });

    test('proporcaoEnergia alimenta a barra da UI', () {
      expect(Mascote(energia: 0).proporcaoEnergia, 0.0);
      expect(Mascote(energia: 50).proporcaoEnergia, 0.5);
      expect(Mascote(energia: 100).proporcaoEnergia, 1.0);
    });
  });

  group('clamp na construcao', () {
    // Protege contra energia fora de faixa vinda do Hive: registro gravado
    // antes de um ajuste em RegrasEnergia, ou dado corrompido.
    test('acima do maximo vira 100', () {
      expect(Mascote(energia: 999).energia, 100);
    });

    test('abaixo do minimo vira 0', () {
      expect(Mascote(energia: -5).energia, 0);
    });
  });

  group('RF03/RF04: aplicar sessao', () {
    test('sessao concluida soma energia', () {
      final resultado = Mascote(energia: 50).aplicar(
        sessao(StatusSessao.concluida),
      );

      expect(resultado.energia, 50 + RegrasEnergia.deltaSessaoConcluida);
      expect(resultado.energia, 65);
    });

    test('sessao interrompida subtrai energia', () {
      final resultado = Mascote(energia: 50).aplicar(
        sessao(StatusSessao.interrompida),
      );

      expect(resultado.energia, 50 + RegrasEnergia.deltaSessaoInterrompida);
      expect(resultado.energia, 40);
    });

    test('clamp no teto: 95 + concluida para em 100, nao 110', () {
      final resultado = Mascote(energia: 95).aplicar(
        sessao(StatusSessao.concluida),
      );

      expect(resultado.energia, 100);
      expect(resultado.estado, EstadoMascote.feliz);
    });

    test('clamp no piso: 5 + interrompida para em 0, nao -5', () {
      final resultado = Mascote(energia: 5).aplicar(
        sessao(StatusSessao.interrompida),
      );

      expect(resultado.energia, 0);
      expect(resultado.estado, EstadoMascote.cansado);
    });

    test('transicao Neutro -> Feliz cruzando o limiar', () {
      final antes = Mascote(energia: 60);
      expect(antes.estado, EstadoMascote.neutro);

      final depois = antes.aplicar(sessao(StatusSessao.concluida));
      expect(depois.energia, 75);
      expect(depois.estado, EstadoMascote.feliz);
    });

    test('transicao Neutro -> Cansado cruzando o limiar', () {
      final antes = Mascote(energia: 35);
      expect(antes.estado, EstadoMascote.neutro);

      final depois = antes.aplicar(sessao(StatusSessao.interrompida));
      expect(depois.energia, 25);
      expect(depois.estado, EstadoMascote.cansado);
    });

    test('aplicar nao muta o mascote original', () {
      final original = Mascote(energia: 50);
      original.aplicar(sessao(StatusSessao.concluida));

      expect(original.energia, 50);
    });
  });
}
