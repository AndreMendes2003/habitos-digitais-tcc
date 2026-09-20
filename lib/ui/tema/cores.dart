/// Paleta do app. Ponto único de definição de cor.
///
/// Nenhum widget declara `Color(0x...)` nem usa `Colors.*` — mesma regra que
/// RegrasEnergia aplica aos parâmetros numéricos: se o valor aparece em dois
/// lugares, um dos dois vai ficar para trás numa revisão.
///
/// AS TRÊS CORES DE ESTADO (feliz/neutro/cansado) espelham a FSM do mascote,
/// que é DERIVADA da energia. Elas não são decoração: são a leitura visual do
/// mesmo estado, então mudar uma aqui muda o significado na tela inteira.
///
/// `alerta` é reservada ao uso de redes sociais ACIMA do limite diário. Não
/// usar para erro genérico, nem para sessão interrompida — uma sessão
/// interrompida não é um erro do usuário, e pintá-la de vermelho de alerta
/// confundiria as duas coisas.
library;

import 'package:flutter/material.dart' show Color, HSLColor;

abstract final class Cores {
  // --- Identidade -----------------------------------------------------------

  static const Color primaria = Color(0xFF4C5FD5);

  // --- Estados do mascote (FSM derivada da energia) -------------------------

  static const Color feliz = Color(0xFF35B87A);
  static const Color neutro = Color(0xFFE8C547);
  static const Color cansado = Color(0xFF6B7A99);

  /// SÓ para uso de redes sociais acima do limite diário.
  static const Color alerta = Color(0xFFD9534F);

  // --- Superfícies ----------------------------------------------------------

  static const Color fundo = Color(0xFFFBF7F2);
  static const Color fundoEscuro = Color(0xFF14131A);

  static const Color superficie = Color(0xFFFFFFFF);
  static const Color superficieEscura = Color(0xFF1E1C26);

  // --- Texto ----------------------------------------------------------------

  static const Color textoPrimario = Color(0xFF1C1B22);
  static const Color textoSecundario = Color(0xFF6B6880);

  /// No escuro o texto inverte contra a superfície escura. Derivado das
  /// superfícies claras de propósito: são os mesmos dois tons, trocados de
  /// papel, e não uma segunda paleta para manter em sincronia.
  static const Color textoPrimarioEscuro = Color(0xFFF3F1F7);
  static const Color textoSecundarioEscuro = Color(0xFFA8A4BC);

  // --- Derivações -----------------------------------------------------------

  /// Tom mais escuro da própria cor, para a base do [BotaoPrincipal].
  ///
  /// Calculado, e não um token novo por variante: a base do botão não é uma
  /// decisão de paleta, é sempre "esta cor, mais escura". Fixar um token para
  /// cada variante criaria pares que podem sair de sincronia quando a cor
  /// original mudar.
  static Color tomEscuro(Color cor, {double fator = 0.18}) {
    final hsl = HSLColor.fromColor(cor);
    return hsl.withLightness((hsl.lightness - fator).clamp(0.0, 1.0)).toColor();
  }
}
