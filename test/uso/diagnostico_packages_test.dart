import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/uso/medicao_uso.dart';
import 'package:habitos_digitais/uso/servico_uso.dart';

/// RF04, diagnóstico: os TRÊS casos de cada app da lista curada precisam
/// aparecer separados no log.
///
/// Zero minuto é o valor de um app não usado, de um app não instalado e de um
/// package name digitado errado. Sem separar, uma lista inteira de nomes
/// errados leria como uma semana exemplar.
void main() {
  const curada = {'com.instagram.android', 'com.pinterest', 'com.errado.nome'};

  /// Fake do PackageManager: só os nomes passados existem no "aparelho".
  ServicoUso servicoCom(Set<String> instaladosNoAparelho) => ServicoUso(
        packages: curada,
        verificarInstalado: (package) async =>
            instaladosNoAparelho.contains(package),
      );

  test('separa uso, instalado sem uso e nao instalado', () async {
    final servico = servicoCom({'com.instagram.android', 'com.pinterest'});

    // Instagram usado hoje; Pinterest instalado e parado; com.errado.nome não
    // resolve no PackageManager.
    const medicao = MedicaoUso(
      permissaoConcedida: true,
      minutos: 42,
      packagesEncontrados: {'com.instagram.android': 42},
    );

    final situacoes = await servico.diagnosticarPackages(medicao);

    expect(situacoes['com.instagram.android'], SituacaoPackage.comUsoHoje);
    expect(situacoes['com.pinterest'], SituacaoPackage.instaladoSemUso);
    expect(situacoes['com.errado.nome'], SituacaoPackage.naoInstalado);
  });

  test('rotulos sao os tres do logcat, com os minutos do package', () {
    const medicao = MedicaoUso(
      permissaoConcedida: true,
      minutos: 55,
      packagesEncontrados: {'com.instagram.android': 42, 'com.pinterest': 13},
    );

    // 42, e nao 55: o total do dia sai na linha de cima. Repeti-lo aqui faria
    // cada app parecer ter consumido o dia inteiro.
    expect(
      ServicoUso.rotulo(SituacaoPackage.comUsoHoje,
          medicao.packagesEncontrados['com.instagram.android']),
      'USO_42_MIN',
    );
    expect(
      ServicoUso.rotulo(SituacaoPackage.instaladoSemUso, null),
      'INSTALADO_SEM_USO_HOJE',
    );
    expect(
      ServicoUso.rotulo(SituacaoPackage.naoInstalado, null),
      'NAO_INSTALADO',
    );
  });

  test('app da lista sem uso e sem instalacao nao vira "sem uso"', () async {
    // Aparelho onde NADA da lista está instalado: o caso que denuncia package
    // name errado. Se isto virasse instaladoSemUso, o erro ficaria invisível.
    final servico = servicoCom(const {});

    final situacoes = await servico.diagnosticarPackages(
      const MedicaoUso(permissaoConcedida: true, minutos: 0),
    );

    expect(
      situacoes.values,
      everyElement(SituacaoPackage.naoInstalado),
    );
  });

  test('falha na consulta nao derruba o diagnostico', () async {
    // A medição é o dado real; o diagnóstico é auxiliar. Uma exceção do
    // PackageManager não pode levar a medição junto.
    final servico = ServicoUso(
      packages: curada,
      verificarInstalado: (_) async => throw Exception('PackageManager caiu'),
    );

    final situacoes = await servico.diagnosticarPackages(
      const MedicaoUso(permissaoConcedida: true, minutos: 0),
    );

    expect(situacoes.length, curada.length);
    expect(situacoes.values, everyElement(SituacaoPackage.naoInstalado));
  });
}
