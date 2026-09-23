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
    Future<bool> Function(String)? verificarInstalado,
  })  : _packages = packages ?? ClassificadorRedesSociais.packages,
        _relogio = relogio ?? DateTime.now,
        _verificarInstalado = verificarInstalado ?? _consultarPackageManager;

  final Set<String> _packages;
  final DateTime Function() _relogio;

  /// Injetável: a consulta real é estática e só responde num aparelho.
  final Future<bool> Function(String) _verificarInstalado;

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

  /// Situação de CADA package da lista curada, com os três casos separados.
  ///
  /// Package name errado soma 0 sem erro nenhum. Sem uso hoje também soma 0.
  /// Os dois casos são indistinguíveis olhando só o total — por isso cada
  /// package ausente da medição é consultado no PackageManager.
  ///
  /// Público e sem `debugPrint` para poder ser testado com um verificador
  /// falso: o log é uma leitura deste mapa, não uma segunda classificação.
  Future<Map<String, SituacaoPackage>> diagnosticarPackages(
    MedicaoUso medicao,
  ) async {
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

    return situacoes;
  }

  /// TODO(remover antes da entrega): diagnóstico da classificação.
  ///
  /// Um rótulo por caso, para separar no logcat o que o total esconde:
  ///
  ///   USO_42_MIN              o package apareceu na janela medida
  ///   INSTALADO_SEM_USO_HOJE  existe no aparelho, zero legítimo
  ///   NAO_INSTALADO           o PackageManager não resolve o nome
  Future<void> _registrarDiagnostico(MedicaoUso medicao) async {
    final situacoes = await diagnosticarPackages(medicao);

    debugPrint('[USO] total hoje: ${medicao.minutos} min');

    // Ordem fixa pela lista curada: o log de duas execuções diferentes fica
    // comparável linha a linha.
    for (final package in _packages) {
      debugPrint(
        '[USO]   $package = '
        '${rotulo(situacoes[package], medicao.packagesEncontrados[package])}',
      );
    }

    final naoInstalados = situacoes.entries
        .where((e) => e.value == SituacaoPackage.naoInstalado)
        .map((e) => e.key);
    if (naoInstalados.isNotEmpty) {
      debugPrint(
        '[USO]   ^ NAO_INSTALADO pode ser package name errado no '
        'ClassificadorRedesSociais — confira antes de concluir que o '
        'app não existe no aparelho.',
      );
    }
  }

  /// O rótulo de uma situação, isolado para que o teste verifique o texto
  /// que vai para o logcat, e não uma reconstrução dele.
  ///
  /// [minutos] são os do PACKAGE, não o total do dia: o total já sai na
  /// linha de cima, e repeti-lo em cada linha faria oito apps parecerem ter
  /// o mesmo uso.
  static String rotulo(SituacaoPackage? situacao, int? minutos) {
    switch (situacao) {
      case SituacaoPackage.comUsoHoje:
        // Zero aqui NÃO é ausência de uso: o package só entra em
        // `packagesEncontrados` com foreground > 0, e os minutos são o
        // truncamento de um valor abaixo de 60s. "USO_0_MIN" lia como o
        // mesmo nada que INSTALADO_SEM_USO_HOJE — justamente a confusão que
        // estes rótulos existem para desfazer.
        return (minutos ?? 0) > 0 ? 'USO_${minutos}_MIN' : 'USO_MENOS_DE_1_MIN';
      case SituacaoPackage.instaladoSemUso:
        return 'INSTALADO_SEM_USO_HOJE';
      case SituacaoPackage.naoInstalado:
      case null:
        return 'NAO_INSTALADO';
    }
  }

  /// Uma falha na consulta não pode derrubar a medição, que é o dado real.
  Future<bool> _estaInstalado(String packageName) async {
    try {
      return await _verificarInstalado(packageName);
    } catch (erro) {
      debugPrint('[USO]   falha ao consultar $packageName: $erro');
      return false;
    }
  }

  /// `getAppInfo` devolve `null` quando o PackageManager não resolve o nome.
  ///
  /// Usa o próprio usage_stats em vez de `device_apps`: o pacote já está no
  /// projeto e o `device_apps` está descontinuado no pub.dev. No Android 11+
  /// a consulta só enxerga os packages declarados em `<queries>` no
  /// AndroidManifest — a lista de lá espelha a do ClassificadorRedesSociais,
  /// e o teste `manifest_queries_test.dart` falha se as duas divergirem.
  static Future<bool> _consultarPackageManager(String packageName) async =>
      await UsageStats.getAppInfo(packageName) != null;
}
