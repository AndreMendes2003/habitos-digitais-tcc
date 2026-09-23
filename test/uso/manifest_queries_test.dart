import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/uso/classificador_redes_sociais.dart';

/// Guarda do espelho entre a lista curada e o `<queries>` do AndroidManifest.
///
/// No Android 11+ (API 30) o PackageManager só enxerga os packages declarados
/// em `<queries>`. Um app da lista que não esteja lá responde como se não
/// estivesse instalado — o diagnóstico grava NAO_INSTALADO e o autor vai
/// caçar um package name que está certo.
///
/// O XML não consegue ler a constante Dart, então o espelho é manual. Este
/// teste é o que impede a divergência de passar despercebida.
void main() {
  test('todo package da lista curada esta declarado em <queries>', () {
    final manifesto = File('android/app/src/main/AndroidManifest.xml');
    expect(manifesto.existsSync(), isTrue,
        reason: 'rode a suite a partir da raiz do projeto');

    final xml = manifesto.readAsStringSync();

    final declarados = RegExp(r'<package\s+android:name="([^"]+)"')
        .allMatches(xml)
        .map((m) => m.group(1))
        .toSet();

    final faltando =
        ClassificadorRedesSociais.packages.difference(declarados.cast());

    expect(
      faltando,
      isEmpty,
      reason: 'sem <package android:name="..."/> o Android 11+ esconde o app '
          'do PackageManager e o diagnostico mente',
    );
  });

  test('nao ha package declarado a mais, fora da lista curada', () {
    // A direcao inversa: um package que saiu da constante e ficou no XML vira
    // visibilidade concedida sem motivo declarado no artigo.
    final xml =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    final declarados = RegExp(r'<package\s+android:name="([^"]+)"')
        .allMatches(xml)
        .map((m) => m.group(1)!)
        .toSet();

    expect(
      declarados.difference(ClassificadorRedesSociais.packages),
      isEmpty,
    );
  });
}
