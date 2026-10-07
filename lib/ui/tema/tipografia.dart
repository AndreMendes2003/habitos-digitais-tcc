/// Escala tipográfica do app, em Nunito empacotada (assets/fontes/).
///
/// Sem google_fonts: ele baixa a fonte na primeira execução, e o piloto não
/// pode depender de rede para desenhar texto. Só existem os pesos 400, 600 e
/// 700 no pubspec — um estilo com outro peso cairia no mais próximo deles.
///
/// Cinco estilos, e só. Cada um existe porque tem um papel distinto na
/// hierarquia; um sexto tamanho "quase igual" a outro é o começo de uma tela
/// que não se parece com as demais.
///
/// As cores NÃO entram aqui: quem resolve cor é o ThemeData, para que o mesmo
/// estilo sirva no claro e no escuro sem duplicação.
library;

import 'package:flutter/material.dart';

abstract final class Tipografia {
  /// Nome da família declarada no pubspec.
  static const String familia = 'Nunito';

  /// 32 bold — número ou palavra única que domina a tela.
  static const TextStyle display =
      TextStyle(fontFamily: familia, fontSize: 32, fontWeight: FontWeight.w700);

  /// 24 bold — título de tela ou de bloco.
  static const TextStyle titulo =
      TextStyle(fontFamily: familia, fontSize: 24, fontWeight: FontWeight.w700);

  /// 16 regular — texto corrido, o padrão.
  static const TextStyle corpo =
      TextStyle(fontFamily: familia, fontSize: 16, fontWeight: FontWeight.w400);

  /// 14 semibold — rótulo de botão e de campo.
  static const TextStyle rotulo =
      TextStyle(fontFamily: familia, fontSize: 14, fontWeight: FontWeight.w600);

  /// 12 regular — legenda, dado auxiliar.
  static const TextStyle micro =
      TextStyle(fontFamily: familia, fontSize: 12, fontWeight: FontWeight.w400);

  /// 64 bold — FORA DA ESCALA de propósito.
  ///
  /// O contador regressivo da sessão de foco não é texto: é um mostrador que
  /// precisa ser legível de longe, com o celular apoiado na mesa. Está aqui,
  /// e não como literal na tela, porque continua sendo uma decisão de design
  /// — só que uma com um único uso legítimo.
  static const TextStyle cronometro =
      TextStyle(fontFamily: familia, fontSize: 64, fontWeight: FontWeight.w700);
}
