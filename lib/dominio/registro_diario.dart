/// Registro de um dia de uso (RF07, camada de dados).
///
/// Uma entrada por data, chaveada por `yyyy-MM-dd`. É o insumo do cálculo de
/// sequência — nada aqui é exibido; a parte visual do RF07 continua fora do
/// MVP.
///
/// O QUE É ARMAZENADO x O QUE É DERIVADO: só entra na caixa o que não dá para
/// recalcular. `limiteRespeitado` e `cumprido` continuam sendo GETTERS — mas
/// calculados sobre [limiteDiarioMinutos], que é GRAVADO.
///
/// POR QUE O LIMITE É GRAVADO: os parâmetros de RegrasEnergia são
/// declaradamente provisórios, a calibrar no piloto. Se o critério viesse do
/// valor ATUAL, subir o limite de 120 para 180 no meio do piloto reescreveria
/// retroativamente o passado — dias que o usuário de fato estourou passariam
/// a constar como cumpridos, e a sequência dele mudaria sozinha da noite para
/// o dia. Gravando o limite vigente, cada dia é julgado pela régua que valia
/// quando foi vivido, e a recalibração afeta só os dias seguintes.
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
    this.limiteDiarioMinutos = RegrasEnergia.limiteDiarioRedesSociaisMinutos,
    this.ehBaseline = false,
  }) : dia = apenasData(dia);

  /// Dia sem nenhuma leitura de uso: o RF04 não mediu (sem permissão, ou
  /// falha na consulta). Não é dia cumprido nem dia falhado — é lacuna.
  factory RegistroDiario.lacuna(
    DateTime dia, {
    int energiaFinal = 0,
    int limiteDiarioMinutos = RegrasEnergia.limiteDiarioRedesSociaisMinutos,
  }) {
    return RegistroDiario(
      dia: dia,
      minutosRedesSociais: 0,
      sessoesConcluidas: 0,
      sessoesInterrompidas: 0,
      energiaFinal: energiaFinal,
      houveMedicao: false,
      limiteDiarioMinutos: limiteDiarioMinutos,
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

  /// Limite diário de rede social EM VIGOR no dia, em minutos.
  ///
  /// Preenchido a partir de RegrasEnergia no momento da gravação. Registros
  /// anteriores a este campo assumem o limite atual ao serem lidos — é a
  /// única suposição possível, e vale para os dias em que o limite era de
  /// fato esse.
  final int limiteDiarioMinutos;

  /// Dia CAPTURADO RETROATIVAMENTE, anterior à instalação do app.
  ///
  /// É a linha de base: o comportamento do usuário antes de qualquer
  /// intervenção. O dado é real e medido pelo mesmo método dos demais — o que
  /// muda é que ele não foi VIVIDO com o app, e por isso não entra na
  /// contagem de sequência.
  ///
  /// [cumprido] e [falhou] continuam refletindo a classificação verdadeira do
  /// dia: se o usuário estourou o limite naquela terça, o registro diz isso,
  /// e é justamente esse o dado da linha de base. Quem decide o que CONTA é
  /// CalculoSequencia, não este modelo.
  final bool ehBaseline;

  String get chave => chaveDe(dia);

  /// Lacuna: dia sem medição. Não conta a favor nem contra na sequência.
  bool get ehLacuna => !houveMedicao;

  /// Limite do DIA respeitado. Usa o limite gravado no registro, e não o
  /// valor atual de RegrasEnergia: o passado é julgado pela régua que valia
  /// quando foi vivido.
  bool get limiteRespeitado => minutosRedesSociais <= limiteDiarioMinutos;

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
    int? limiteDiarioMinutos,
    bool? ehBaseline,
  }) {
    return RegistroDiario(
      dia: dia,
      minutosRedesSociais: minutosRedesSociais ?? this.minutosRedesSociais,
      sessoesConcluidas: sessoesConcluidas ?? this.sessoesConcluidas,
      sessoesInterrompidas: sessoesInterrompidas ?? this.sessoesInterrompidas,
      energiaFinal: energiaFinal ?? this.energiaFinal,
      houveMedicao: houveMedicao ?? this.houveMedicao,
      limiteDiarioMinutos: limiteDiarioMinutos ?? this.limiteDiarioMinutos,
      ehBaseline: ehBaseline ?? this.ehBaseline,
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
        'limiteDiarioMinutos': limiteDiarioMinutos,
        'ehBaseline': ehBaseline,
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
      // Registro gravado antes deste campo existir: assume o limite atual.
      limiteDiarioMinutos: mapa['limiteDiarioMinutos'] as int? ??
          RegrasEnergia.limiteDiarioRedesSociaisMinutos,
      // Registro anterior a este campo é, por definição, de intervenção:
      // a captura de baseline nasceu junto com o campo.
      ehBaseline: mapa['ehBaseline'] as bool? ?? false,
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
        other.houveMedicao == houveMedicao &&
        other.limiteDiarioMinutos == limiteDiarioMinutos &&
        other.ehBaseline == ehBaseline;
  }

  @override
  int get hashCode => Object.hash(
        dia,
        minutosRedesSociais,
        sessoesConcluidas,
        sessoesInterrompidas,
        energiaFinal,
        houveMedicao,
        limiteDiarioMinutos,
        ehBaseline,
      );

  @override
  String toString() => 'RegistroDiario($chave, '
      'min: $minutosRedesSociais, '
      'sessoes: $sessoesConcluidas/$sessoesInterrompidas, '
      'energia: $energiaFinal, '
      'limite: $limiteDiarioMinutos, '
      '${ehBaseline ? 'BASE ' : ''}'
      '${houveMedicao ? (cumprido ? 'cumprido' : 'falhou') : 'lacuna'})';
}
