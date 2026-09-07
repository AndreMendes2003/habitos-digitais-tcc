import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../dominio/sessao_foco.dart';

/// Histórico persistido de sessões de foco (RF02 + RF01).
///
/// Append-only: sessão finalizada não muda mais, então a caixa só cresce.
class RepositorioSessoes {
  RepositorioSessoes(this._caixa);

  static const String nomeCaixa = 'sessoes';

  final Box<Map<dynamic, dynamic>> _caixa;

  /// Da mais recente para a mais antiga.
  ///
  /// Registros ilegíveis são PULADOS, não propagados: um único mapa corrompido
  /// (ou gravado num formato anterior) não pode derrubar a tela e levar junto
  /// todo o histórico bom, que é o dado que vai para o artigo.
  List<SessaoFoco> todas() {
    final sessoes = <SessaoFoco>[];
    for (final mapa in _caixa.values) {
      try {
        sessoes.add(SessaoFoco.doMapa(mapa));
      } catch (erro) {
        debugPrint('[HIVE] registro de sessão ilegível, pulado: $erro');
      }
    }
    return sessoes.reversed.toList();
  }

  Future<void> adicionar(SessaoFoco sessao) {
    return _caixa.add(sessao.paraMapa());
  }
}
