/// Resultado de uma medição de uso de redes sociais (RF04).
///
/// Só dados: sem plugin, sem Hive. É o que atravessa a fronteira entre
/// `lib/uso/` (que mede) e o domínio (que decide o que fazer com o número).
library;

class MedicaoUso {
  const MedicaoUso({
    required this.permissaoConcedida,
    required this.minutos,
    this.packagesEncontrados = const {},
  });

  /// Medição impossível: sem PACKAGE_USAGE_STATS não há o que penalizar.
  const MedicaoUso.semPermissao()
      : permissaoConcedida = false,
        minutos = 0,
        packagesEncontrados = const {};

  final bool permissaoConcedida;

  /// Minutos em primeiro plano hoje, somados apenas sobre os packages da
  /// lista do ClassificadorRedesSociais.
  final int minutos;

  /// Quais packages da lista apareceram no dia, com seus minutos.
  /// Serve de diagnóstico: package name errado nunca aparece aqui.
  final Map<String, int> packagesEncontrados;

  @override
  String toString() => 'MedicaoUso(permissao: $permissaoConcedida, '
      'minutos: $minutos, encontrados: ${packagesEncontrados.length})';
}

/// Situação de cada package da lista no aparelho, para o diagnóstico.
///
/// A distinção que importa: "instalado, sem uso hoje" é um resultado legítimo;
/// "não instalado" num aparelho onde o app existe é sintoma de package name
/// errado na lista do classificador.
enum SituacaoPackage {
  comUsoHoje,
  instaladoSemUso,
  naoInstalado,
}
