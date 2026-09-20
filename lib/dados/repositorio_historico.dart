import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../dominio/registro_diario.dart';

/// Histórico diário persistido (RF07).
///
/// Caixa própria, uma entrada por data, chaveada por `yyyy-MM-dd`. Chave
/// natural, e não `add()` sequencial: escrever o dia corrente várias vezes ao
/// longo do dia é o caso NORMAL aqui — o registro é atualizado a cada
/// avaliação de uso — e com chave por data isso é um `put` idempotente em vez
/// de uma caixa cheia de versões do mesmo dia.
class RepositorioHistorico {
  RepositorioHistorico(this._caixa);

  static const String nomeCaixa = 'historico';

  final Box<Map<dynamic, dynamic>> _caixa;

  /// `null` quando o dia não tem registro — que é justamente a lacuna do
  /// cálculo de sequência, e por isso NÃO vira um registro zerado aqui.
  RegistroDiario? carregarDia(DateTime dia) {
    final mapa = _caixa.get(RegistroDiario.chaveDe(dia));
    if (mapa == null) return null;

    try {
      return RegistroDiario.doMapa(mapa);
    } catch (erro) {
      debugPrint('[HIVE] registro diário ilegível, ignorado: $erro');
      return null;
    }
  }

  /// Todos os registros, em ordem cronológica.
  ///
  /// Registros ilegíveis são PULADOS, não propagados — mesma política do
  /// RepositorioSessoes: um mapa corrompido não pode levar junto o histórico
  /// bom, que é o dado que vai para o artigo.
  List<RegistroDiario> todos() {
    final registros = <RegistroDiario>[];
    for (final mapa in _caixa.values) {
      try {
        registros.add(RegistroDiario.doMapa(mapa));
      } catch (erro) {
        debugPrint('[HIVE] registro diário ilegível, pulado: $erro');
      }
    }
    return registros..sort((a, b) => a.dia.compareTo(b.dia));
  }

  Future<void> salvar(RegistroDiario registro) {
    return _caixa.put(registro.chave, registro.paraMapa());
  }
}
