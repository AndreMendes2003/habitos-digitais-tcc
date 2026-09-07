import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../dominio/avaliacao_uso.dart';

/// Persistência da avaliação diária de uso (RF04).
///
/// Um único registro: só o dia corrente interessa. Histórico de dias
/// anteriores está fora do escopo do MVP.
class RepositorioUso {
  RepositorioUso(this._caixa);

  static const String nomeCaixa = 'uso';
  static const String _chaveAvaliacao = 'avaliacao';

  final Box<Map<dynamic, dynamic>> _caixa;

  /// `null` quando nunca houve avaliação, ou quando o registro está ilegível
  /// — nesse caso o ControladorUso simplesmente começa o dia do zero, que é
  /// mais seguro do que derrubar a tela.
  AvaliacaoUsoDiaria? carregar() {
    final mapa = _caixa.get(_chaveAvaliacao);
    if (mapa == null) return null;

    try {
      return AvaliacaoUsoDiaria.doMapa(mapa);
    } catch (erro) {
      debugPrint('[HIVE] avaliação de uso ilegível, ignorada: $erro');
      return null;
    }
  }

  Future<void> salvar(AvaliacaoUsoDiaria avaliacao) {
    return _caixa.put(_chaveAvaliacao, avaliacao.paraMapa());
  }
}
