/// Cache das animações do mascote (RF01).
///
/// POR QUE UM CACHE: as três composições somam ~1,1 MB de JSON, sendo 777 KB
/// só no CatCry. Decodificar isso no meio de uma troca de estado daria um
/// engasgo visível — e a troca de estado acontece justamente no momento em
/// que o usuário acabou de concluir ou interromper uma sessão, que é quando a
/// resposta da tela mais importa.
///
/// Carregadas UMA VEZ em [precarregar], chamado no boot antes do `runApp`.
/// Depois disso o widget lê do mapa em memória, sem tocar no disco.
///
/// QUANDO O CACHE ESTÁ VAZIO: [de] devolve `null` e o widget desenha o vão
/// sem animação, em vez de estourar. É o estado normal em teste de widget,
/// que não chama [precarregar] — nenhum teste deve depender de decodificar
/// 1 MB de JSON para verificar um rótulo de texto.
library;

import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

import '../../dominio/mascote.dart';

abstract final class AnimacoesMascote {
  /// Um arquivo por estado da FSM. O mapa é exaustivo sobre [EstadoMascote]
  /// de propósito: acrescentar um estado novo quebra aqui, em vez de cair
  /// silenciosamente num `default` sem animação.
  static const Map<EstadoMascote, String> caminhos = {
    EstadoMascote.feliz: 'assets/animacoes/CatLove.json',
    EstadoMascote.neutro: 'assets/animacoes/CatLaugh.json',
    EstadoMascote.cansado: 'assets/animacoes/CatCry.json',
  };

  /// Caixa ocupada pela ARTE dentro do canvas de 500x500 de cada animação,
  /// em coordenadas normalizadas (0..1).
  ///
  /// As três vêm centralizadas num quadrado com muita folga: sobram de 24% a
  /// 36% de vazio acima e ~25% abaixo. Renderizadas inteiras, o mascote fica
  /// pequeno e separado do rótulo por um vão que não é layout — é o canvas.
  ///
  /// MEDIDO, NÃO ESTIMADO: cada animação foi renderizada em 13 quadros ao
  /// longo do loop e estes são os limites dos pixels não transparentes, em
  /// união. Amostrar vários quadros importa porque a arte se move — medir só
  /// o quadro 0 cortaria o topo do pulo.
  ///
  /// Os ARQUIVOS não são alterados: o recorte acontece na renderização, então
  /// a declaração de licença em docs/assets.md continua valendo.
  static const Map<EstadoMascote, Rect> conteudo = {
    EstadoMascote.feliz: Rect.fromLTRB(0.156, 0.254, 0.832, 0.730),
    EstadoMascote.neutro: Rect.fromLTRB(0.110, 0.360, 0.880, 0.754),
    EstadoMascote.cansado: Rect.fromLTRB(0.086, 0.238, 0.934, 0.756),
  };

  /// Sobra deixada em volta da caixa medida, para a borda suavizada da arte
  /// não encostar no recorte.
  static const double folga = 0.015;

  /// A caixa medida com a folga, ainda dentro de 0..1.
  static Rect conteudoComFolga(EstadoMascote estado) {
    final r = conteudo[estado]!;
    return Rect.fromLTRB(
      (r.left - folga).clamp(0.0, 1.0),
      (r.top - folga).clamp(0.0, 1.0),
      (r.right + folga).clamp(0.0, 1.0),
      (r.bottom + folga).clamp(0.0, 1.0),
    );
  }

  static final Map<EstadoMascote, LottieComposition> _cache = {};

  /// Já carregado? Serve para a UI decidir entre animação e vão vazio.
  static bool get pronto => _cache.length == caminhos.length;

  static LottieComposition? de(EstadoMascote estado) => _cache[estado];

  /// Decodifica os três arquivos e guarda em memória.
  ///
  /// Em paralelo, e não em sequência: são três leituras independentes, e
  /// serializá-las só somaria latência no boot.
  ///
  /// Uma falha em um arquivo NÃO derruba o app: o estado correspondente fica
  /// sem animação e o resto da tela continua de pé. Um asset faltando é
  /// problema de empacotamento, não motivo para tela branca.
  static Future<void> precarregar() async {
    await Future.wait(
      caminhos.entries.map((entrada) async {
        try {
          _cache[entrada.key] =
              await AssetLottie(entrada.value).load();
        } catch (erro) {
          debugPrint(
            '[MASCOTE] falha ao carregar ${entrada.value}: $erro',
          );
        }
      }),
    );

    debugPrint('[MASCOTE] animações em cache: ${_cache.length}'
        '/${caminhos.length}');
  }

  /// Só para teste: devolve o cache ao estado inicial.
  @visibleForTesting
  static void limparCache() => _cache.clear();
}
