import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Marca de que a captura retroativa de baseline já aconteceu.
///
/// Caixa própria, com um único registro. Não vai junto do histórico porque o
/// `RepositorioHistorico.todos()` percorre todos os valores da caixa tentando
/// lê-los como RegistroDiario — a marca cairia ali como registro ilegível a
/// cada leitura. E não vai na caixa do RF04, que responde por outra coisa.
class RepositorioBaseline {
  RepositorioBaseline(this._caixa);

  static const String nomeCaixa = 'baseline';
  static const String _chave = 'captura';

  final Box<Map<dynamic, dynamic>> _caixa;

  /// A captura é irreversível de propósito: uma vez registrada, reabrir o app
  /// nunca mais sobrescreve dias que o usuário já viveu com ele instalado.
  bool get jaCapturado => _caixa.containsKey(_chave);

  DateTime? get capturadoEm {
    final mapa = _caixa.get(_chave);
    if (mapa == null) return null;
    try {
      return DateTime.parse(mapa['capturadoEm'] as String);
    } catch (erro) {
      debugPrint('[BASELINE] marca ilegível: $erro');
      return null;
    }
  }

  int get diasCapturados => (_caixa.get(_chave)?['diasCapturados'] as int?) ?? 0;

  Future<void> marcar(DateTime quando, int dias) {
    return _caixa.put(_chave, {
      'capturadoEm': quando.toIso8601String(),
      'diasCapturados': dias,
    });
  }
}
