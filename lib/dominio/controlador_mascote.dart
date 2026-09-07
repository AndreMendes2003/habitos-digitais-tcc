import 'package:flutter/foundation.dart';

import 'mascote.dart';
import 'sessao_foco.dart';

/// Segura o [Mascote] atual e avisa a UI quando a ENERGIA muda (RF01).
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

  /// RF03/RF04: ponto onde o resultado da sessão vira ENERGIA.
  Future<void> registrarSessao(SessaoFoco sessao) async {
    _mascote = _mascote.aplicar(sessao);
    // Notifica antes de gravar: a UI não deve esperar o disco para reagir.
    notifyListeners();
    await aoPersistir?.call(_mascote);
  }
}
