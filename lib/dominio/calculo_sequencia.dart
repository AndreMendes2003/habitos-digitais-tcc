/// Cálculo de sequência (streak) sobre os registros diários (RF07).
///
/// Função pura sobre uma lista: sem Hive, sem widget, sem relógio implícito —
/// o "hoje" entra por parâmetro, como em todo o resto do domínio.
///
/// AS TRÊS CATEGORIAS DE DIA, e por que a do meio existe:
///
///   cumprido  mediu e ficou dentro do limite    → soma 1
///   falhou    mediu e estourou o limite         → zera
///   lacuna    não mediu, ou não há registro     → ATRAVESSA
///   baseline  dia anterior à instalação         → ATRAVESSA
///
/// O dia de BASELINE atravessa pelo mesmo motivo da lacuna, por outro
/// caminho: ele tem dado, e dado bom, mas não foi vivido com o app. Contá-lo
/// daria ao usuário uma sequência de 7 dias no primeiro boot — premiando
/// comportamento anterior à intervenção e destruindo o valor da sequência
/// como indicador de aderência.
///
/// A lacuna não é neutra por conveniência: sem permissão de uso o app não
/// tem como saber se o dia foi bom ou ruim. Contá-la como falha puniria o
/// usuário por um dado que o sistema não coletou; contá-la como sucesso
/// premiaria revogar a permissão. Atravessar é a única leitura que não
/// inventa um fato.
///
/// DIA SEM REGISTRO NENHUM também é lacuna: app não aberto no dia é
/// exatamente o caso "não houve medição".
library;

import 'registro_diario.dart';

/// Um dia da janela exibida, com ou sem registro.
///
/// Existe para que a UI não precise saber que "sem registro" e "registro sem
/// medição" são a mesma coisa para o usuário — os dois são lacuna, e a regra
/// de qual é qual fica aqui, não no widget.
class DiaDaSequencia {
  const DiaDaSequencia({required this.dia, this.registro});

  final DateTime dia;

  /// `null` quando o app não gravou nada naquele dia.
  final RegistroDiario? registro;

  bool get cumprido => registro?.cumprido ?? false;
  bool get falhou => registro?.falhou ?? false;
  bool get ehLacuna => !cumprido && !falhou;

  /// Dia capturado retroativamente, anterior à instalação.
  bool get ehBaseline => registro?.ehBaseline ?? false;

  bool ehHoje(DateTime hoje) => dia == RegistroDiario.apenasData(hoje);
}

abstract final class CalculoSequencia {
  /// Dias consecutivos cumpridos contando de [hoje] para trás.
  ///
  /// O dia corrente entra pela regra normal: enquanto estiver abaixo do
  /// limite ele já conta, e passa a quebrar assim que o estourar.
  static int atual(List<RegistroDiario> registros, DateTime hoje) {
    if (registros.isEmpty) return 0;

    final porDia = _indexar(registros);
    final primeiroDia = _maisAntigo(porDia.values);
    final diaCorrente = RegistroDiario.apenasData(hoje);

    var sequencia = 0;
    var cursor = diaCorrente;

    // Para no dia anterior ao primeiro registro: além dali é tudo lacuna e a
    // contagem não teria onde terminar.
    while (!cursor.isBefore(primeiroDia)) {
      final registro = porDia[RegistroDiario.chaveDe(cursor)];

      // Baseline: nem soma nem quebra, qualquer que seja a classificação.
      if (registro != null && !registro.ehBaseline) {
        if (registro.falhou) break;
        if (registro.cumprido) sequencia++;
      }
      // Lacuna (registro nulo ou sem medição): não soma, não quebra.

      cursor = _diaAnterior(cursor);
    }

    return sequencia;
  }

  /// Maior sequência já alcançada, incluindo a que está em curso.
  ///
  /// Varre do primeiro registro até [hoje] para que uma sequência corrente
  /// maior que qualquer uma do passado apareça aqui também.
  static int maior(List<RegistroDiario> registros, DateTime hoje) {
    if (registros.isEmpty) return 0;

    final porDia = _indexar(registros);
    final diaCorrente = RegistroDiario.apenasData(hoje);
    var cursor = _maisAntigo(porDia.values);

    var maiorSequencia = 0;
    var corrente = 0;

    while (!cursor.isAfter(diaCorrente)) {
      final registro = porDia[RegistroDiario.chaveDe(cursor)];

      if (registro != null && !registro.ehBaseline) {
        if (registro.falhou) {
          corrente = 0;
        } else if (registro.cumprido) {
          corrente++;
          if (corrente > maiorSequencia) maiorSequencia = corrente;
        }
      }
      // Lacuna e baseline: `corrente` fica como está e a contagem atravessa.

      cursor = _diaSeguinte(cursor);
    }

    return maiorSequencia;
  }

  /// Os registros dos últimos [quantidade] dias até [hoje], em ordem
  /// cronológica. Dias sem registro NÃO são preenchidos: a ausência já é a
  /// informação de lacuna, e inventar um registro vazio aqui o faria parecer
  /// um dado medido.
  static List<RegistroDiario> ultimosDias(
    List<RegistroDiario> registros,
    DateTime hoje, {
    int quantidade = 30,
  }) {
    final diaCorrente = RegistroDiario.apenasData(hoje);
    final primeiroIncluido = DateTime(
      diaCorrente.year,
      diaCorrente.month,
      diaCorrente.day - (quantidade - 1),
    );

    final janela = registros
        .where((r) => !r.dia.isBefore(primeiroIncluido))
        .where((r) => !r.dia.isAfter(diaCorrente))
        .toList()
      ..sort((a, b) => a.dia.compareTo(b.dia));

    return List.unmodifiable(janela);
  }

  /// Os últimos [quantidade] dias até [hoje], em ordem cronológica, com UM
  /// item por dia — inclusive os dias sem registro.
  ///
  /// Diferente de [ultimosDias], que devolve só o que existe: aqui os buracos
  /// aparecem como [DiaDaSequencia] sem registro, porque uma grade de
  /// calendário precisa de célula para todo dia. A lista tem sempre
  /// [quantidade] itens, então o layout não muda conforme o histórico cresce.
  static List<DiaDaSequencia> grade(
    List<RegistroDiario> registros,
    DateTime hoje, {
    int quantidade = 30,
  }) {
    final porDia = _indexar(registros);
    final diaCorrente = RegistroDiario.apenasData(hoje);

    return [
      for (var atras = quantidade - 1; atras >= 0; atras--)
        () {
          final dia = DateTime(
            diaCorrente.year,
            diaCorrente.month,
            diaCorrente.day - atras,
          );
          return DiaDaSequencia(
            dia: dia,
            registro: porDia[RegistroDiario.chaveDe(dia)],
          );
        }(),
    ];
  }

  /// Último registro de cada data. Protege contra duplicatas vindas de um
  /// histórico montado à mão em teste.
  static Map<String, RegistroDiario> _indexar(List<RegistroDiario> registros) {
    return {for (final registro in registros) registro.chave: registro};
  }

  static DateTime _maisAntigo(Iterable<RegistroDiario> registros) {
    return registros
        .map((r) => r.dia)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  // Aritmética pelo construtor, e não por Duration: normaliza no calendário
  // local e não escorrega numa eventual mudança de horário.
  static DateTime _diaAnterior(DateTime dia) =>
      DateTime(dia.year, dia.month, dia.day - 1);

  static DateTime _diaSeguinte(DateTime dia) =>
      DateTime(dia.year, dia.month, dia.day + 1);
}
