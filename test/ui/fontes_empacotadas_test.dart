import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/ui/tema/tipografia.dart';

/// Guarda da tipografia offline.
///
/// O google_fonts baixa a fonte na primeira execução; sem rede ele cai na
/// fonte do sistema sem erro nenhum, e no piloto isso passaria despercebido
/// até alguém comparar duas capturas de tela. Este teste impede a volta da
/// dependência e o pubspec apontando para um arquivo que não existe.
void main() {
  late String pubspec;

  setUp(() {
    final arquivo = File('pubspec.yaml');
    expect(
      arquivo.existsSync(),
      isTrue,
      reason: 'rode a suite a partir da raiz do projeto',
    );
    pubspec = arquivo.readAsStringSync();
  });

  test('google_fonts nao e dependencia', () {
    expect(
      RegExp(r'^\s+google_fonts:', multiLine: true).hasMatch(pubspec),
      isFalse,
    );
  });

  test('a familia da Tipografia esta declarada no pubspec', () {
    expect(pubspec, contains('- family: ${Tipografia.familia}'));
  });

  test('os tres pesos da escala estao empacotados e existem em disco', () {
    final assets =
        RegExp(r'- asset:\s*(assets/fontes/\S+\.ttf)\s*\n\s*weight:\s*(\d+)')
            .allMatches(pubspec)
            .map((m) => (caminho: m.group(1)!, peso: int.parse(m.group(2)!)))
            .toList();

    expect(assets.map((a) => a.peso).toSet(), {400, 600, 700});
    for (final asset in assets) {
      expect(
        File(asset.caminho).existsSync(),
        isTrue,
        reason: '${asset.caminho} declarado no pubspec mas ausente',
      );
    }
  });
}
