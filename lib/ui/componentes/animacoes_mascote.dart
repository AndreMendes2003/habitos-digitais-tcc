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

import 'package:flutter/foundation.dart';
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
