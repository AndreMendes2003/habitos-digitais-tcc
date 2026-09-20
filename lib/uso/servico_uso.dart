import 'package:flutter/foundation.dart';
import 'package:usage_stats/usage_stats.dart';

import 'classificador_redes_sociais.dart';
import 'medicao_uso.dart';

/// Mede tempo de rede social no dia corrente (RF04).
///
/// ESTE MÓDULO NÃO ALTERA ENERGIA. Ele só consulta o UsageStatsManager e
/// devolve minutos. Quem transforma minutos em delta é o ControladorUso;
/// quem escreve energia é o ControladorMascote.
class ServicoUso {
  ServicoUso({
    Set<String>? packages,
    DateTime Function()? relogio,
  })  : _packages = packages ?? ClassificadorRedesSociais.packages,
        _relogio = relogio ?? DateTime.now;

  final Set<String> _packages;
  final DateTime Function() _relogio;

  /// Soma o foreground de hoje (00:00 até agora) dos packages classificados.
  Future<MedicaoUso> medirHoje() async {
    final agora = _relogio();
    final inicioDoDia = DateTime(agora.year, agora.month, agora.day);

    final medicao = await medirJanela(inicioDoDia, agora);
    if (!medicao.permissaoConcedida) return medicao;

    await _registrarDiagnostico(medicao);
    return medicao;
  }

  /// Mede um DIA inteiro, de meia-noite a meia-noite local.
  ///
  /// Usado pela captura de baseline. Aritmética pelo construtor, e não por
  /// Duration: normaliza no calendário local e não escorrega numa eventual
  /// mudança de horário.
  ///
  /// Sem o bloco de diagnóstico de propósito: ele custa até 8 consultas ao
  /// PackageManager, e rodá-lo uma vez por dia capturado desperdiçaria meio
  /// segundo no primeiro boot sem acrescentar nada — a lista de packages é a
  /// mesma em todos os dias.
  Future<MedicaoUso> medirDia(DateTime dia) {
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = DateTime(dia.year, dia.month, dia.day + 1);
    return medirJanela(inicio, fim);
  }

  /// NÚCLEO ÚNICO DA MEDIÇÃO. Baseline e intervenção passam por aqui.
  ///
  /// Extraído para que as duas não possam divergir: medir a linha de base com
  /// um método e o período de intervenção com outro invalidaria a comparação
  /// que é o objeto do trabalho.
  ///
  /// queryAndAggregateUsageStats, e NÃO queryUsageStats: o primeiro devolve
  /// um registro por package, já somado pelo próprio Android. O segundo usa
  /// INTERVAL_BEST e pode devolver vários buckets do mesmo package dentro da
  /// janela — somá-los daria contagem dupla, que é o erro mais provável
  /// nesse dado.
  Future<MedicaoUso> medirJanela(DateTime inicio, DateTime fim) async {
    final permitido = await UsageStats.checkUsagePermission() ?? false;
    if (!permitido) {
      // RF04, item 6: sem permissão não se mede e não se penaliza.
      return const MedicaoUso.semPermissao();
    }

    final porPackage = await UsageStats.queryAndAggregateUsageStats(
      inicio,
      fim,
    );

    final encontrados = <String, int>{};
    var totalMs = 0;

    for (final package in _packages) {
      final uso = porPackage[package];
      final ms = uso?.totalTimeInForegroundMs ?? 0;
      if (ms <= 0) continue;

      totalMs += ms;
      encontrados[package] = ms ~/ 60000;
    }

    return MedicaoUso(
      permissaoConcedida: true,
      minutos: totalMs ~/ 60000,
      packagesEncontrados: encontrados,
      // Mapa vazio = o sistema não tem dado dessa janela. Mapa cheio sem
      // nenhum app da lista = zero legítimo de rede social.
      houveDados: porPackage.isNotEmpty,
    );
  }

  /// TODO(remover antes da entrega): diagnóstico da classificação.
  ///
  /// Package name errado soma 0 sem erro nenhum. Sem uso hoje também soma 0.
  /// Os dois casos são indistinguíveis olhando só o total — por isso cada
  /// package ausente é consultado no PackageManager via
  /// `UsageStats.getAppInfo`, que devolve `null` quando não resolve.
  ///
  /// Usa o próprio usage_stats em vez de `device_apps`: o pacote já está no
  /// projeto e o `device_apps` está descontinuado no pub.dev. O
  /// QUERY_ALL_PACKAGES que o Android 11+ exige para essa consulta já está
  /// declarado no AndroidManifest.
  Future<void> _registrarDiagnostico(MedicaoUso medicao) async {
    final situacoes = <String, SituacaoPackage>{};

    for (final package in _packages) {
      if (medicao.packagesEncontrados.containsKey(package)) {
        situacoes[package] = SituacaoPackage.comUsoHoje;
        continue;
      }
      situacoes[package] = await _estaInstalado(package)
          ? SituacaoPackage.instaladoSemUso
          : SituacaoPackage.naoInstalado;
    }

    List<String> naSituacao(SituacaoPackage situacao) => situacoes.entries
        .where((e) => e.value == situacao)
        .map((e) => e.key)
        .toList();

    debugPrint('[USO] total hoje: ${medicao.minutos} min');

    for (final package in naSituacao(SituacaoPackage.comUsoHoje)) {
      debugPrint(
        '[USO]   com uso hoje: $package = '
        '${medicao.packagesEncontrados[package]} min',
      );
    }

    for (final package in naSituacao(SituacaoPackage.instaladoSemUso)) {
      debugPrint('[USO]   instalado, sem uso hoje: $package');
    }

    final naoInstalados = naSituacao(SituacaoPackage.naoInstalado);
    for (final package in naoInstalados) {
      debugPrint('[USO]   NAO INSTALADO no aparelho: $package');
    }
    if (naoInstalados.isNotEmpty) {
      debugPrint(
        '[USO]   ^ confira se o package name está certo no '
        'ClassificadorRedesSociais — um nome errado aparece aqui.',
      );
    }
  }

  /// `getAppInfo` devolve `null` quando o PackageManager não resolve o nome.
  /// Uma falha na consulta não pode derrubar a medição, que é o dado real.
  Future<bool> _estaInstalado(String packageName) async {
    try {
      return await UsageStats.getAppInfo(packageName) != null;
    } catch (erro) {
      debugPrint('[USO]   falha ao consultar $packageName: $erro');
      return false;
    }
  }
}
