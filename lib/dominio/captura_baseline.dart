/// Captura retroativa da linha de base (dias anteriores à instalação).
///
/// POR QUE EXISTE: o trabalho compara comportamento ANTES e DEPOIS da
/// intervenção. Sem uma linha de base, o "antes" só existiria por relato do
/// usuário. O UsageStatsManager guarda o passado recente, então na primeira
/// vez que a permissão é concedida dá para registrar esses dias medidos.
///
/// QUANTOS DIAS: 7, e não mais. O spike F2.0 mediu no S23 que a granularidade
/// diária confiável vai até ~7 dias; além disso o INTERVAL_BEST devolve o
/// bucket semanal ou mensal ecoado em cada dia da faixa, e capturar isso
/// gravaria o total de um mês como se fosse o de um dia.
///
/// UMA VEZ SÓ: quem decide é a marca no RepositorioBaseline, não a ausência
/// de registros. Sem a marca, um usuário que apagasse o histórico ou passasse
/// 30 dias sem abrir o app teria dias já vividos sobrescritos como baseline.
library;

import 'package:flutter/foundation.dart';

import '../dados/repositorio_baseline.dart';
import '../dados/repositorio_historico.dart';
import '../uso/medicao_uso.dart';
import 'regras_energia.dart';
import 'registro_diario.dart';

class CapturaBaseline {
  CapturaBaseline({
    required this.medirDia,
    required this.repositorioHistorico,
    required this.repositorioBaseline,
  });

  /// Quantos dias para trás. Ver a nota sobre o spike F2.0 no topo.
  static const int diasRetroativos = 7;

  /// Mede um dia inteiro. Em `main()` aponta para `ServicoUso.medirDia`, o
  /// MESMO núcleo que mede o dia corrente.
  final Future<MedicaoUso> Function(DateTime dia) medirDia;

  final RepositorioHistorico repositorioHistorico;
  final RepositorioBaseline repositorioBaseline;

  /// Captura os [diasRetroativos] dias ANTERIORES a [hoje]. Devolve quantos
  /// foram gravados; 0 quando a captura já havia acontecido.
  ///
  /// Hoje fica de fora: o dia corrente é do período de intervenção e já é
  /// gravado pelo fluxo normal do RF04, com a medição parcial que vai sendo
  /// atualizada ao longo do dia.
  Future<int> capturarSeNecessario(DateTime hoje) async {
    if (repositorioBaseline.jaCapturado) return 0;

    var gravados = 0;

    for (var atras = diasRetroativos; atras >= 1; atras--) {
      // Aritmética pelo construtor: normaliza no calendário local e cai na
      // meia-noite certa mesmo atravessando mudança de horário.
      final dia = DateTime(hoje.year, hoje.month, hoje.day - atras);

      // Um dia que falhar não pode abortar a captura dos outros: ele entra
      // como lacuna e a varredura segue.
      MedicaoUso medicao;
      try {
        medicao = await medirDia(dia);
      } catch (erro) {
        debugPrint('[BASELINE] falha ao medir $dia: $erro');
        medicao = const MedicaoUso.semPermissao();
      }

      final houveMedicao = medicao.permissaoConcedida && medicao.houveDados;

      await repositorioHistorico.salvar(
        RegistroDiario(
          dia: dia,
          minutosRedesSociais: houveMedicao ? medicao.minutos : 0,
          // O app não existia: não houve sessão de foco nem energia.
          sessoesConcluidas: 0,
          sessoesInterrompidas: 0,
          energiaFinal: 0,
          houveMedicao: houveMedicao,
          limiteDiarioMinutos:
              RegrasEnergia.limiteDiarioRedesSociaisMinutos,
          ehBaseline: true,
        ),
      );
      gravados++;

      debugPrint('[BASELINE] ${RegistroDiario.chaveDe(dia)}: '
          '${houveMedicao ? '${medicao.minutos} min' : 'sem dado'}');
    }

    await repositorioBaseline.marcar(hoje, gravados);
    debugPrint('[BASELINE] captura concluída: $gravados dias');
    return gravados;
  }
}
