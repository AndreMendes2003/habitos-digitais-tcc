/// Montagem do [ThemeData] claro e escuro a partir dos tokens.
///
/// Único lugar que costura cores + tipografia + raios. As telas leem o tema,
/// nunca os tokens de cor diretamente para texto — assim o mesmo widget serve
/// nos dois modos sem `if (escuro)` espalhado.
library;

import 'package:flutter/material.dart';

import 'cores.dart';
import 'espacamento.dart';
import 'tipografia.dart';

abstract final class Tema {
  static ThemeData get claro => _montar(Brightness.light);
  static ThemeData get escuro => _montar(Brightness.dark);

  static ThemeData _montar(Brightness brilho) {
    final escuro = brilho == Brightness.dark;

    final fundo = escuro ? Cores.fundoEscuro : Cores.fundo;
    final superficie = escuro ? Cores.superficieEscura : Cores.superficie;
    final textoPrimario =
        escuro ? Cores.textoPrimarioEscuro : Cores.textoPrimario;
    final textoSecundario =
        escuro ? Cores.textoSecundarioEscuro : Cores.textoSecundario;

    // fromSeed, e não um ColorScheme montado à mão: os componentes do
    // Material 3 usam os papéis derivados (`secondaryContainer`,
    // `surfaceContainerHighest`...), e num esquema parcial esses papéis
    // colapsam sobre as cores base — foi assim que o segmento selecionado do
    // seletor de duração saiu pintado de `feliz`.
    //
    // As cores de estado do mascote NÃO entram no esquema. Elas significam
    // uma coisa só, e emprestá-las ao cromo do Material as transformaria em
    // decoração: verde deixaria de querer dizer "o mascote está feliz".
    final esquema = ColorScheme.fromSeed(
      seedColor: Cores.primaria,
      brightness: brilho,
    ).copyWith(
      primary: Cores.primaria,
      onPrimary: Colors.white,
      error: Cores.alerta,
      onError: Colors.white,
      surface: superficie,
      onSurface: textoPrimario,
    );

    final textos = TextTheme(
      displayLarge: Tipografia.display,
      headlineMedium: Tipografia.titulo,
      bodyLarge: Tipografia.corpo,
      bodyMedium: Tipografia.corpo,
      labelLarge: Tipografia.rotulo,
      labelSmall: Tipografia.micro,
    ).apply(bodyColor: textoPrimario, displayColor: textoPrimario);

    return ThemeData(
      useMaterial3: true,
      brightness: brilho,
      colorScheme: esquema,
      scaffoldBackgroundColor: fundo,
      textTheme: textos,
      // `disabledColor` é o tom do "medindo..." na linha de uso: um estado
      // que ainda não tem valor não deve competir com os que têm.
      disabledColor: textoSecundario,
      dividerTheme: DividerThemeData(
        color: textoSecundario.withValues(alpha: 0.2),
        space: Espacamento.xxl,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: fundo,
        foregroundColor: textoPrimario,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: Tipografia.titulo.copyWith(color: textoPrimario),
      ),
      cardTheme: CardThemeData(
        color: superficie,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Raios.card),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(Tipografia.rotulo),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Raios.pill),
            ),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: Tipografia.corpo.copyWith(color: textoPrimario),
        subtitleTextStyle: Tipografia.micro.copyWith(color: textoSecundario),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: textoSecundario.withValues(alpha: 0.15),
      ),
    );
  }
}
