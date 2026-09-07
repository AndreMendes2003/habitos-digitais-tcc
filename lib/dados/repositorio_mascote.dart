import 'package:hive/hive.dart';

import '../dominio/mascote.dart';
import '../dominio/regras_energia.dart';

/// Persistência da ENERGIA do mascote (RF01).
///
/// Guarda SÓ a energia: o estado Feliz/Neutro/Cansado é derivado dela em
/// [Mascote.estado] e gravá-lo seria uma segunda fonte de verdade.
class RepositorioMascote {
  RepositorioMascote(this._caixa);

  static const String nomeCaixa = 'mascote';
  static const String _chaveEnergia = 'energia';

  final Box<int> _caixa;

  /// Primeira execução (chave ausente) devolve o mascote inicial, Neutro.
  Mascote carregar() {
    return Mascote(
      energia: _caixa.get(_chaveEnergia) ?? RegrasEnergia.energiaInicial,
    );
  }

  Future<void> salvar(Mascote mascote) {
    return _caixa.put(_chaveEnergia, mascote.energia);
  }
}
