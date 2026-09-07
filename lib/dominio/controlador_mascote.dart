import 'package:flutter/foundation.dart';

import 'mascote.dart';
import 'regras_energia.dart';
import 'sessao_foco.dart';

/// Segura o [Mascote] atual e avisa a UI quando a ENERGIA muda (RF01).
///
/// É o ÚNICO lugar do app que escreve energia. Os módulos que produzem os
/// eventos — sessão de foco (RF02) e medição de uso (`lib/uso/`) — apenas
/// calculam ou medem; nenhum deles toca no mascote.
///
/// Não conhece o Hive nem o repositório: recebe a persistência como callback,
/// no mesmo padrão que o ControladorSessao já usa para `relogio` e
/// `aoFinalizarSessao`. É o que mantém `dominio/` sem import de `dados/` sem
/// precisar inventar uma interface e um fake só para testar.
class ControladorMascote extends ChangeNotifier {
  ControladorMascote({Mascote? inicial, this.aoPersistir})
      : _mascote = inicial ?? Mascote();

  /// Chamado depois de cada mudança de energia. Em `main()` aponta para o
  /// RepositorioMascote; em teste, para uma lista.
  final Future<void> Function(Mascote mascote)? aoPersistir;

  Mascote _mascote;
  Mascote get mascote => _mascote;

  /// RF03/RF04, primeiro ramo: desfecho de uma sessão de foco.
  Future<void> registrarSessao(SessaoFoco sessao) {
    return _escrever(
      RegrasEnergia.deltaParaSessao(sessao.status),
      'sessão ${sessao.status.name}',
    );
  }

  /// RF04, segundo ramo: penalidade por tempo excedido em redes sociais.
  ///
  /// Recebe os pontos já calculados (sempre <= 0). Quem mede é `lib/uso/`,
  /// quem aplica a regra e garante idempotência é o ControladorUso.
  Future<void> registrarPenalidadeUso(int pontos) {
    if (pontos == 0) return Future<void>.value();
    return _escrever(pontos, 'uso de redes sociais');
  }

  /// ÚNICA atribuição a [_mascote] em todo o app.
  ///
  /// Todo caminho que mexe em energia passa por aqui, então o log abaixo é a
  /// trilha completa das mudanças no device.
  Future<void> _escrever(int delta, String motivo) async {
    final antes = _mascote;
    _mascote = _mascote.comDelta(delta);

    // Notifica antes de gravar: a UI não deve esperar o disco para reagir.
    notifyListeners();
    debugPrint(
      '[ENERGIA] ${antes.energia} -> ${_mascote.energia} '
      '(delta $delta | $motivo)',
    );

    await aoPersistir?.call(_mascote);
  }
}
