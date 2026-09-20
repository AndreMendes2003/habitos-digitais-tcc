import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/dominio/calculo_sequencia.dart';
import 'package:habitos_digitais/dominio/regras_energia.dart';
import 'package:habitos_digitais/dominio/registro_diario.dart';

/// RF07: regra de sequência. Função pura, sem Hive e sem relógio implícito —
/// o "hoje" entra por parâmetro em toda chamada.
void main() {
  /// Data fixa, longe de virada de mês: os cenários falam em "hoje - N dias"
  /// e não devem depender de quando o teste roda.
  final hoje = DateTime(2026, 9, 20);

  DateTime diasAtras(int n) => DateTime(2026, 9, 20 - n);

  /// Minutos seguramente DENTRO e FORA do limite, derivados de RegrasEnergia.
  /// Escritos assim, e não como 60/300, para que uma recalibração do limite
  /// no piloto não transforme estes testes em falsos negativos.
  final dentroDoLimite = RegrasEnergia.limiteDiarioRedesSociaisMinutos - 1;
  final acimaDoLimite = RegrasEnergia.limiteDiarioRedesSociaisMinutos + 1;

  RegistroDiario dia(
    int atras, {
    required int minutos,
    bool houveMedicao = true,
    int concluidas = 0,
    int interrompidas = 0,
    int energia = 50,
  }) {
    return RegistroDiario(
      dia: diasAtras(atras),
      minutosRedesSociais: minutos,
      sessoesConcluidas: concluidas,
      sessoesInterrompidas: interrompidas,
      energiaFinal: energia,
      houveMedicao: houveMedicao,
    );
  }

  RegistroDiario cumprido(int atras) => dia(atras, minutos: dentroDoLimite);
  RegistroDiario falhou(int atras) => dia(atras, minutos: acimaDoLimite);
  RegistroDiario lacuna(int atras) =>
      dia(atras, minutos: 0, houveMedicao: false);

  group('classificação do dia', () {
    test('no limite exato ainda é dia cumprido', () {
      final registro = dia(
        0,
        minutos: RegrasEnergia.limiteDiarioRedesSociaisMinutos,
      );

      expect(registro.limiteRespeitado, isTrue);
      expect(registro.cumprido, isTrue);
      expect(registro.falhou, isFalse);
    });

    test('um minuto acima do limite é dia falhado', () {
      expect(falhou(0).cumprido, isFalse);
      expect(falhou(0).falhou, isTrue);
    });

    test('sem medição não é cumprido NEM falhado: é lacuna', () {
      final registro = lacuna(0);

      expect(registro.ehLacuna, isTrue);
      expect(registro.cumprido, isFalse);
      expect(registro.falhou, isFalse);
    });
  });

  group('limite gravado no registro', () {
    test('o critério é o limite DO DIA, não o de RegrasEnergia hoje', () {
      // Dia vivido sob um limite mais generoso: 150 min estouravam a regra
      // atual (120), mas nao a que valia naquele dia.
      final sobRegraAntiga = RegistroDiario(
        dia: diasAtras(1),
        minutosRedesSociais: 150,
        sessoesConcluidas: 0,
        sessoesInterrompidas: 0,
        energiaFinal: 50,
        houveMedicao: true,
        limiteDiarioMinutos: 200,
      );

      expect(sobRegraAntiga.limiteDiarioMinutos, 200);
      expect(sobRegraAntiga.limiteRespeitado, isTrue);
      expect(sobRegraAntiga.cumprido, isTrue);
      // Os mesmos 150 min sob a regra atual seriam falha.
      expect(
        150 > RegrasEnergia.limiteDiarioRedesSociaisMinutos,
        isTrue,
        reason: 'o teste perde o sentido se o limite atual passar de 150',
      );
    });

    test('limite ausente assume o valor atual', () {
      final semLimiteExplicito = dia(0, minutos: dentroDoLimite);

      expect(
        semLimiteExplicito.limiteDiarioMinutos,
        RegrasEnergia.limiteDiarioRedesSociaisMinutos,
      );
    });

    test('a sequência respeita o limite de cada dia', () {
      // hoje-1 estourou a regra atual mas nao a dele; nao pode quebrar.
      final registros = [
        cumprido(2),
        RegistroDiario(
          dia: diasAtras(1),
          minutosRedesSociais: 150,
          sessoesConcluidas: 0,
          sessoesInterrompidas: 0,
          energiaFinal: 50,
          houveMedicao: true,
          limiteDiarioMinutos: 200,
        ),
        cumprido(0),
      ];

      expect(CalculoSequencia.atual(registros, hoje), 3);
    });
  });

  group('sequência atual', () {
    test('histórico vazio: primeiro dia de uso não tem sequência', () {
      expect(CalculoSequencia.atual(const [], hoje), 0);
      expect(CalculoSequencia.maior(const [], hoje), 0);
    });

    test('sequência simples: quatro dias seguidos dentro do limite', () {
      final registros = [cumprido(3), cumprido(2), cumprido(1), cumprido(0)];

      expect(CalculoSequencia.atual(registros, hoje), 4);
    });

    test('dia acima do limite quebra a sequência', () {
      // hoje-4 e hoje-3 cumpridos, hoje-2 estourou, hoje-1 e hoje cumpridos.
      final registros = [
        cumprido(4),
        cumprido(3),
        falhou(2),
        cumprido(1),
        cumprido(0),
      ];

      // Só conta o trecho depois da quebra.
      expect(CalculoSequencia.atual(registros, hoje), 2);
    });

    test('a quebra vale mesmo sendo hoje', () {
      final registros = [cumprido(2), cumprido(1), falhou(0)];

      expect(CalculoSequencia.atual(registros, hoje), 0);
    });

    test('lacuna no meio não quebra: a contagem atravessa', () {
      // Dia sem permissão no meio de uma sequência boa.
      final registros = [
        cumprido(3),
        cumprido(2),
        lacuna(1),
        cumprido(0),
      ];

      // 3 dias cumpridos; a lacuna não soma nem zera.
      expect(CalculoSequencia.atual(registros, hoje), 3);
    });

    test('dia sem registro nenhum também atravessa', () {
      // hoje-2 simplesmente não existe na caixa: app não foi aberto.
      final registros = [cumprido(3), cumprido(1), cumprido(0)];

      expect(CalculoSequencia.atual(registros, hoje), 3);
    });

    test('lacuna não segura sequência nenhuma por si só', () {
      final registros = [lacuna(2), lacuna(1), lacuna(0)];

      expect(CalculoSequencia.atual(registros, hoje), 0);
    });

    test('dia corrente em andamento conta enquanto está abaixo do limite', () {
      // O registro de hoje é reescrito a cada avaliação; aqui ele ainda está
      // dentro do limite.
      final emAndamento = [cumprido(1), dia(0, minutos: 10)];
      expect(CalculoSequencia.atual(emAndamento, hoje), 2);

      // Mais tarde no mesmo dia o usuário estoura o limite: o dia vira quebra
      // sem que nada mais no histórico mude.
      final estourou = [cumprido(1), dia(0, minutos: acimaDoLimite)];
      expect(CalculoSequencia.atual(estourou, hoje), 0);
    });

    test('registros fora de ordem dão o mesmo resultado', () {
      final registros = [cumprido(0), cumprido(2), cumprido(1)];

      expect(CalculoSequencia.atual(registros, hoje), 3);
    });
  });

  group('maior sequência', () {
    test('guarda a maior do passado mesmo depois de uma quebra', () {
      final registros = [
        cumprido(6),
        cumprido(5),
        cumprido(4),
        cumprido(3),
        falhou(2),
        cumprido(1),
        cumprido(0),
      ];

      expect(CalculoSequencia.atual(registros, hoje), 2);
      expect(CalculoSequencia.maior(registros, hoje), 4);
    });

    test('a sequência em curso entra na conta da maior', () {
      final registros = [cumprido(2), cumprido(1), cumprido(0)];

      expect(CalculoSequencia.atual(registros, hoje), 3);
      expect(CalculoSequencia.maior(registros, hoje), 3);
    });

    test('lacuna atravessa também no cálculo da maior', () {
      final registros = [
        cumprido(4),
        cumprido(3),
        lacuna(2),
        cumprido(1),
        cumprido(0),
      ];

      expect(CalculoSequencia.maior(registros, hoje), 4);
    });

    test('histórico só de dias falhados não gera sequência', () {
      final registros = [falhou(2), falhou(1), falhou(0)];

      expect(CalculoSequencia.maior(registros, hoje), 0);
    });
  });

  group('grade de dias', () {
    test('tem sempre uma célula por dia, mesmo com histórico vazio', () {
      final grade = CalculoSequencia.grade(const [], hoje);

      // Tamanho fixo: a grade nao pode encolher conforme o historico cresce.
      expect(grade, hasLength(30));
      expect(grade.every((d) => d.ehLacuna), isTrue);
      expect(grade.every((d) => d.registro == null), isTrue);
    });

    test('sai em ordem cronológica e termina em hoje', () {
      final grade = CalculoSequencia.grade([cumprido(0)], hoje);

      expect(grade.first.dia, diasAtras(29));
      expect(grade.last.dia, diasAtras(0));
      expect(grade.last.ehHoje(hoje), isTrue);
      expect(grade.first.ehHoje(hoje), isFalse);
    });

    test('classifica cada célula pelo registro do dia', () {
      final grade = CalculoSequencia.grade(
        [cumprido(2), falhou(1), lacuna(0)],
        hoje,
      );
      DiaDaSequencia celula(int atras) =>
          grade.firstWhere((d) => d.dia == diasAtras(atras));

      expect(celula(2).cumprido, isTrue);
      expect(celula(1).falhou, isTrue);
      // Registro sem medicao e dia sem registro caem na mesma categoria:
      // para quem olha a grade, os dois sao "nao sei".
      expect(celula(0).ehLacuna, isTrue);
      expect(celula(5).ehLacuna, isTrue);
    });

    test('dia fora da janela não aparece', () {
      final grade = CalculoSequencia.grade([cumprido(40)], hoje);

      expect(grade.every((d) => d.registro == null), isTrue);
    });
  });

  group('janela dos últimos 30 dias', () {
    test('devolve em ordem cronológica e corta o que é mais antigo', () {
      final registros = [
        cumprido(40),
        cumprido(30),
        cumprido(29),
        cumprido(1),
        cumprido(0),
      ];

      final janela = CalculoSequencia.ultimosDias(registros, hoje);

      // hoje-29 é o dia mais antigo que cabe numa janela de 30 dias.
      expect(janela, hasLength(3));
      expect(janela.first.dia, diasAtras(29));
      expect(janela.last.dia, diasAtras(0));
      expect(
        janela.map((r) => r.dia).toList(),
        [diasAtras(29), diasAtras(1), diasAtras(0)],
      );
    });

    test('dias sem registro não são preenchidos', () {
      final registros = [cumprido(5), cumprido(0)];

      // A ausência é a própria lacuna; inventar registro aqui faria um dia
      // não medido parecer medido.
      expect(CalculoSequencia.ultimosDias(registros, hoje), hasLength(2));
    });

    test('histórico vazio devolve lista vazia', () {
      expect(CalculoSequencia.ultimosDias(const [], hoje), isEmpty);
    });
  });
}
