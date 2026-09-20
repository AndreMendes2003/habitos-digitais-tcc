/// Registro de um dia de uso (RF07, camada de dados).
///
/// Uma entrada por data, chaveada por `yyyy-MM-dd`. É o insumo do cálculo de
/// sequência — nada aqui é exibido; a parte visual do RF07 continua fora do
/// MVP.
///
/// O QUE É ARMAZENADO x O QUE É DERIVADO: só entra na caixa o que não dá para
/// recalcular. `limiteRespeitado` e `cumprido` são GETTERS, no mesmo critério
/// que o projeto já aplica ao estado Feliz/Neutro/Cansado do mascote: gravar
/// um valor que depende de RegrasEnergia criaria uma segunda fonte de verdade
/// e, como os parâmetros são declaradamente provisórios, o histórico gravado
/// antes de uma recalibração passaria a mentir sobre o próprio critério.
/// Derivando, recalibrar o limite reinterpreta o histórico inteiro de graça.
library;

import 'regras_energia.dart';

class RegistroDiario {
  RegistroDiario({
    required DateTime dia,
    required this.minutosRedesSociais,
    required this.sessoesConcluidas,
    required this.sessoesInterrompidas,
    required this.energiaFinal,
    required this.houveMedicao,
  }) : dia = apenasData(dia);

  /// Dia sem nenhuma leitura de uso: o RF04 não mediu (sem permissão, ou
  /// falha na consulta). Não é dia cumprido nem dia falhado — é lacuna.
  factory RegistroDiario.lacuna(DateTime dia, {int energiaFinal = 0}) {
    return RegistroDiario(
      dia: dia,
      minutosRedesSociais: 0,
      sessoesConcluidas: 0,
      sessoesInterrompidas: 0,
      energiaFinal: energiaFinal,
      houveMedicao: false,
    );
  }

  /// Data sem hora. Comparar DateTime cheio nunca daria igual — mesma razão
  /// de [AvaliacaoUsoDiaria.apenasData].
  static DateTime apenasData(DateTime momento) {
    return DateTime(momento.year, momento.month, momento.day);
  }

  /// Chave da caixa: `yyyy-MM-dd`. Ordenável como string, o que deixa a
  /// leitura em ordem cronológica ser um sort simples.
  static String chaveDe(DateTime dia) {
    final mes = dia.month.toString().padLeft(2, '0');
    final diaDoMes = dia.day.toString().padLeft(2, '0');
    return '${dia.year}-$mes-$diaDoMes';
  }

  final DateTime dia;

  /// Minutos medidos pelo RF04 no dia. Zero quando [houveMedicao] é falso.
  final int minutosRedesSociais;

  final int sessoesConcluidas;
  final int sessoesInterrompidas;

  /// Energia do mascote na última escrita do dia.
  final int energiaFinal;

  /// Houve leitura válida do UsageStatsManager: permissão concedida e
  /// consulta bem-sucedida.
  final bool houveMedicao;

  String get chave => chaveDe(dia);

  /// Lacuna: dia sem medição. Não conta a favor nem contra na sequência.
  bool get ehLacuna => !houveMedicao;

  /// Limite diário do RF04 respeitado. Lido de RegrasEnergia a cada chamada,
  /// nunca gravado.
  bool get limiteRespeitado =>
      minutosRedesSociais <= RegrasEnergia.limiteDiarioRedesSociaisMinutos;

  /// Critério de "dia cumprido": mediu, e ficou dentro do limite.
  bool get cumprido => houveMedicao && limiteRespeitado;

  /// Dia que QUEBRA a sequência: mediu, e estourou o limite.
  bool get falhou => houveMedicao && !limiteRespeitado;

  RegistroDiario copiaCom({
    int? minutosRedesSociais,
    int? sessoesConcluidas,
    int? sessoesInterrompidas,
    int? energiaFinal,
    bool? houveMedicao,
  }) {
    return RegistroDiario(
      dia: dia,
      minutosRedesSociais: minutosRedesSociais ?? this.minutosRedesSociais,
      sessoesConcluidas: sessoesConcluidas ?? this.sessoesConcluidas,
      sessoesInterrompidas: sessoesInterrompidas ?? this.sessoesInterrompidas,
      energiaFinal: energiaFinal ?? this.energiaFinal,
      houveMedicao: houveMedicao ?? this.houveMedicao,
    );
  }

  /// Serializa em primitivos, sem TypeAdapter — mesma escolha de SessaoFoco.
  Map<String, dynamic> paraMapa() => {
        'dia': chave,
        'minutosRedesSociais': minutosRedesSociais,
        'sessoesConcluidas': sessoesConcluidas,
        'sessoesInterrompidas': sessoesInterrompidas,
        'energiaFinal': energiaFinal,
        'houveMedicao': houveMedicao,
      };

  /// Aceita `Map` cru porque o Hive devolve `Map<dynamic, dynamic>`.
  ///
  /// Lança se o registro estiver ilegível; quem decide o que fazer com isso é
  /// o repositório.
  factory RegistroDiario.doMapa(Map<dynamic, dynamic> mapa) {
    return RegistroDiario(
      dia: DateTime.parse(mapa['dia'] as String),
      minutosRedesSociais: mapa['minutosRedesSociais'] as int,
      sessoesConcluidas: mapa['sessoesConcluidas'] as int,
      sessoesInterrompidas: mapa['sessoesInterrompidas'] as int,
      energiaFinal: mapa['energiaFinal'] as int,
      houveMedicao: mapa['houveMedicao'] as bool,
    );
  }

  /// Igualdade por valor: é o que permite ao EstadoApp comparar o registro
  /// recém-montado com o que já está na caixa e pular a escrita quando nada
  /// mudou.
  @override
  bool operator ==(Object other) {
    return other is RegistroDiario &&
        other.dia == dia &&
        other.minutosRedesSociais == minutosRedesSociais &&
        other.sessoesConcluidas == sessoesConcluidas &&
        other.sessoesInterrompidas == sessoesInterrompidas &&
        other.energiaFinal == energiaFinal &&
        other.houveMedicao == houveMedicao;
  }

  @override
  int get hashCode => Object.hash(
        dia,
        minutosRedesSociais,
        sessoesConcluidas,
        sessoesInterrompidas,
        energiaFinal,
        houveMedicao,
      );

  @override
  String toString() => 'RegistroDiario($chave, '
      'min: $minutosRedesSociais, '
      'sessoes: $sessoesConcluidas/$sessoesInterrompidas, '
      'energia: $energiaFinal, '
      '${houveMedicao ? (cumprido ? 'cumprido' : 'falhou') : 'lacuna'})';
}
