/// Leitura do estado físico da tela, para o RNF01.
///
/// POR QUE ISTO EXISTE: o Android emite `paused` tanto quando o usuário sai
/// do app quanto quando a tela apaga. Do lado Dart os dois eventos são
/// idênticos — e tratá-los igual faz o app punir exatamente o comportamento
/// que ele quer incentivar, que é largar o celular bloqueado.
///
/// Só transporta os dois valores crus do Android. A decisão de interromper
/// ou não é do ControladorSessao, que continua sem conhecer este arquivo.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class EstadoTela {
  const EstadoTela({required this.ligada, required this.bloqueada});

  /// Fallback quando o canal não responde.
  ///
  /// Tela LIGADA de propósito: assumir desligada manteria viva uma sessão que
  /// o usuário abandonou de verdade, inflando as sessões concluídas — que são
  /// o dado do piloto. Interromper é o erro conservador.
  const EstadoTela.desconhecido()
      : ligada = true,
        bloqueada = false;

  /// `PowerManager.isInteractive`.
  final bool ligada;

  /// `KeyguardManager.isKeyguardLocked`.
  final bool bloqueada;

  @override
  String toString() =>
      'EstadoTela(isInteractive: $ligada, isKeyguardLocked: $bloqueada)';
}

/// Adaptador do MethodChannel declarado em MainActivity.kt.
class ServicoTela {
  ServicoTela({MethodChannel? canal}) : _canal = canal ?? _padrao;

  static const MethodChannel _padrao = MethodChannel('habitos_digitais/tela');

  final MethodChannel _canal;

  /// Consulta o Android. NUNCA lança: uma falha aqui não pode derrubar o
  /// tratamento do ciclo de vida, que é o caminho por onde a sessão termina.
  Future<EstadoTela> consultar() async {
    try {
      final resposta =
          await _canal.invokeMapMethod<String, dynamic>('estadoDaTela');
      if (resposta == null) return const EstadoTela.desconhecido();

      return EstadoTela(
        ligada: resposta['isInteractive'] as bool? ?? true,
        bloqueada: resposta['isKeyguardLocked'] as bool? ?? false,
      );
    } catch (erro) {
      // Em teste de widget e no desktop não há canal nenhum: cai aqui e o app
      // segue com o comportamento antigo.
      debugPrint('[LIFECYCLE] falha ao consultar o estado da tela: $erro');
      return const EstadoTela.desconhecido();
    }
  }
}
