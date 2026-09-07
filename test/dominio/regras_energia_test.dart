import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dominio/regras_energia.dart';

/// RF04, segundo ramo: a regra da penalidade por uso de redes sociais.
///
/// Limites em numeros LITERAIS de proposito, como nos testes da FSM: sao eles
/// que travam o requisito. Se alguem calibrar as constantes no piloto, o teste
/// quebra e a mudanca vira decisao consciente.
void main() {
  group('penalidadeAcumulada', () {
    test('zero uso nao penaliza', () {
      expect(RegrasEnergia.penalidadeAcumulada(0), 0);
    });

    test('abaixo do limite nao penaliza', () {
      expect(RegrasEnergia.penalidadeAcumulada(119), 0);
    });

    test('LIMIAR EXATO (120) nao penaliza', () {
      // O limite e tolerado: penaliza acima dele, nao nele.
      expect(RegrasEnergia.penalidadeAcumulada(120), 0);
    });

    test('excedente incompleto nao fecha bloco', () {
      // 29 min acima do limite: falta 1 para o primeiro bloco de 30.
      expect(RegrasEnergia.penalidadeAcumulada(149), 0);
    });

    test('primeiro bloco completo custa -5', () {
      expect(RegrasEnergia.penalidadeAcumulada(150), -5);
    });

    test('segundo bloco so conta quando completa', () {
      expect(RegrasEnergia.penalidadeAcumulada(179), -5);
      expect(RegrasEnergia.penalidadeAcumulada(180), -10);
    });

    test('escala linear ate o teto', () {
      expect(RegrasEnergia.penalidadeAcumulada(210), -15);
      expect(RegrasEnergia.penalidadeAcumulada(240), -20);
      expect(RegrasEnergia.penalidadeAcumulada(270), -25);
    });

    test('TETO de -30 no dia', () {
      // 180 min acima do limite = 6 blocos = -30.
      expect(RegrasEnergia.penalidadeAcumulada(300), -30);
    });

    test('acima do teto continua em -30', () {
      expect(RegrasEnergia.penalidadeAcumulada(400), -30);
      expect(RegrasEnergia.penalidadeAcumulada(1440), -30);
    });

    test('nunca devolve energia', () {
      for (var minutos = 0; minutos <= 600; minutos += 7) {
        expect(RegrasEnergia.penalidadeAcumulada(minutos), lessThanOrEqualTo(0));
      }
    });
  });
}
