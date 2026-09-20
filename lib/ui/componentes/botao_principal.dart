/// Botão base do app.
///
/// A borda inferior sólida é a affordance: o botão parece ter espessura, e ao
/// pressionar ela some e a face desce os mesmos 4px — o botão "afunda" até o
/// próprio apoio. Não é enfeite. Num app de hábito o toque precisa devolver
/// uma confirmação física imediata, antes de qualquer resultado na tela.
///
/// A ALTURA TOTAL NÃO MUDA ao pressionar: a face desce e a margem inferior
/// cresce na mesma medida. Sem isso o botão encolheria e empurraria o layout
/// a cada toque.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema/cores.dart';
import '../tema/espacamento.dart';
import '../tema/tipografia.dart';

enum VarianteBotao {
  /// Ação principal da tela. Só uma por tela.
  primario,

  /// Ação de apoio, menos peso visual.
  secundario,
}

class BotaoPrincipal extends StatefulWidget {
  const BotaoPrincipal({
    required this.rotulo,
    required this.onPressed,
    this.variante = VarianteBotao.primario,
    super.key,
  });

  final String rotulo;

  /// `null` desabilita: sem afundar, sem vibrar, sem base.
  ///
  /// Nulo em vez de um `bool desabilitado` porque é impossível esquecer de
  /// desligar o callback — o estado visual e o comportamento saem do mesmo
  /// dado, e não de dois que podem discordar.
  final VoidCallback? onPressed;

  final VarianteBotao variante;

  bool get habilitado => onPressed != null;

  @override
  State<BotaoPrincipal> createState() => _BotaoPrincipalState();
}

class _BotaoPrincipalState extends State<BotaoPrincipal> {
  /// Espessura da base. Igual ao passo mínimo da escala, para o botão
  /// afundar exatamente um degrau do ritmo do layout.
  static const double _espessuraBase = 4;

  /// Curta de propósito: acima de ~100ms o afundar deixa de ser resposta ao
  /// toque e vira animação.
  static const Duration _duracao = Duration(milliseconds: 70);

  bool _pressionado = false;

  void _definirPressionado(bool valor) {
    if (!widget.habilitado || _pressionado == valor) return;
    setState(() => _pressionado = valor);
  }

  void _aoTocar() {
    // Antes do callback: o retorno tátil é sobre o toque ter sido recebido,
    // não sobre o que ele causou.
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (corFace, corTexto) = _cores(tema);
    final afundado = _pressionado && widget.habilitado;

    return Semantics(
      button: true,
      enabled: widget.habilitado,
      label: widget.rotulo,
      child: GestureDetector(
        onTapDown: (_) => _definirPressionado(true),
        onTapUp: (_) => _definirPressionado(false),
        onTapCancel: () => _definirPressionado(false),
        onTap: widget.habilitado ? _aoTocar : null,
        child: AnimatedContainer(
          duration: _duracao,
          curve: Curves.easeOut,
          // A soma top+bottom é sempre _espessuraBase: a face desce, o vão
          // desce junto, e o espaço ocupado no layout não muda.
          margin: EdgeInsets.only(
            top: afundado ? _espessuraBase : 0,
            bottom: afundado ? 0 : _espessuraBase,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: Espacamento.lg,
            horizontal: Espacamento.xl,
          ),
          decoration: BoxDecoration(
            color: corFace,
            borderRadius: BorderRadius.circular(Raios.botao),
            // Sombra sem blur e deslocada: é uma borda inferior sólida, e não
            // uma sombra. Como `boxShadow`, ela acompanha o arredondamento
            // dos cantos, o que uma Border não faria.
            boxShadow: afundado || !widget.habilitado
                ? const []
                : [
                    BoxShadow(
                      color: Cores.tomEscuro(corFace),
                      offset: const Offset(0, _espessuraBase),
                    ),
                  ],
          ),
          child: Center(
            widthFactor: null,
            heightFactor: 1,
            child: Text(
              widget.rotulo,
              textAlign: TextAlign.center,
              style: Tipografia.rotulo.copyWith(color: corTexto),
            ),
          ),
        ),
      ),
    );
  }

  /// (face, texto) para a variante e o estado atuais.
  (Color, Color) _cores(ThemeData tema) {
    if (!widget.habilitado) {
      // Desabilitado não é uma terceira cor de marca: é a superfície do tema
      // rebaixada, para ler como "inerte" e não como "outra ação".
      return (
        tema.disabledColor.withValues(alpha: 0.18),
        tema.disabledColor,
      );
    }

    return switch (widget.variante) {
      VarianteBotao.primario => (Cores.primaria, Colors.white),
      VarianteBotao.secundario => (tema.colorScheme.surface, Cores.primaria),
    };
  }
}
