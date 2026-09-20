/// Escala de espaçamento e raios de canto.
///
/// Escala de 4: todo padding, margem e gap do app sai daqui. O objetivo não é
/// economizar digitação — é que dois espaços que parecem iguais na tela sejam
/// de fato iguais, e que ajustar o ritmo vertical seja uma edição num lugar.
library;

abstract final class Espacamento {
  /// 4 — separação mínima, entre um rótulo e o que ele rotula.
  static const double xs = 4;

  /// 8 — entre itens de um mesmo grupo.
  static const double sm = 8;

  /// 12 — padding interno de controles.
  static const double md = 12;

  /// 16 — padding padrão de tela e de card.
  static const double lg = 16;

  /// 24 — entre blocos distintos da mesma seção.
  static const double xl = 24;

  /// 32 — entre seções.
  static const double xxl = 32;

  /// 48 — respiro grande, antes de uma ação isolada.
  static const double xxxl = 48;
}

abstract final class Raios {
  /// 16 — cards e superfícies.
  static const double card = 16;

  /// 12 — botões.
  static const double botao = 12;

  /// Cápsula. Valor alto o bastante para o Flutter clampar na metade da
  /// altura, o que dá a cápsula em qualquer tamanho sem calcular nada.
  static const double pill = 999;
}
