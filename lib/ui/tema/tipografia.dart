/// Escala tipográfica do app, em Nunito (google_fonts).
///
/// Cinco estilos, e só. Cada um existe porque tem um papel distinto na
/// hierarquia; um sexto tamanho "quase igual" a outro é o começo de uma tela
/// que não se parece com as demais.
///
/// As cores NÃO entram aqui: quem resolve cor é o ThemeData, para que o mesmo
/// estilo sirva no claro e no escuro sem duplicação.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class Tipografia {
  /// 32 bold — número ou palavra única que domina a tela.
  static TextStyle get display =>
      GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w700);

  /// 24 bold — título de tela ou de bloco.
  static TextStyle get titulo =>
      GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700);

  /// 16 regular — texto corrido, o padrão.
  static TextStyle get corpo =>
      GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w400);

  /// 14 semibold — rótulo de botão e de campo.
  static TextStyle get rotulo =>
      GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600);

  /// 12 regular — legenda, dado auxiliar.
  static TextStyle get micro =>
      GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w400);

  /// 64 bold — FORA DA ESCALA de propósito.
  ///
  /// O contador regressivo da sessão de foco não é texto: é um mostrador que
  /// precisa ser legível de longe, com o celular apoiado na mesa. Está aqui,
  /// e não como literal na tela, porque continua sendo uma decisão de design
  /// — só que uma com um único uso legítimo.
  static TextStyle get cronometro =>
      GoogleFonts.nunito(fontSize: 64, fontWeight: FontWeight.w700);
}
