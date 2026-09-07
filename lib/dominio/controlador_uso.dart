import 'package:flutter/foundation.dart';

import '../uso/medicao_uso.dart';
import 'avaliacao_uso.dart';
import 'regras_energia.dart';

/// Traduz minutos de rede social em penalidade de ENERGIA (RF04).
///
/// NÃO escreve energia: [avaliar] devolve o delta e quem aplica é o
/// ControladorMascote. Também não mede: recebe a medição por injeção, o que
/// mantém a regra testável sem plugin nem MethodChannel.
class ControladorUso extends ChangeNotifier {
  ControladorUso({
    required this.medir,
    AvaliacaoUsoDiaria? avaliacaoInicial,
    this.aoPersistir,
    DateTime Function()? relogio,
  })  : _relogio = relogio ?? DateTime.now,
        _avaliacao = avaliacaoInicial;

  /// Fonte da medição. Em `main()` aponta para `ServicoUso.medirHoje`.
  final Future<MedicaoUso> Function() medir;

  final Future<void> Function(AvaliacaoUsoDiaria avaliacao)? aoPersistir;

  final DateTime Function() _relogio;

  AvaliacaoUsoDiaria? _avaliacao;

  /// Impede que resume e fim de sessão, disparando juntos, leiam o mesmo
  /// estado e apliquem o desconto duas vezes.
  bool _avaliando = false;

  int _minutosHoje = 0;
  bool _permissaoConcedida = true;

  /// Minutos medidos na última avaliação, para a linha de status da UI.
  int get minutosHoje => _minutosHoje;
  bool get permissaoConcedida => _permissaoConcedida;

  /// Total já cobrado hoje, em pontos de energia (<= 0).
  int get penalidadeJaAplicada {
    final avaliacao = _avaliacao;
    if (avaliacao == null || !avaliacao.ehDoMesmoDia(_relogio())) return 0;
    return RegrasEnergia.penalidadeAcumulada(avaliacao.minutosContabilizados);
  }

  /// Mede, calcula o delta ainda não cobrado e o devolve. Sempre <= 0.
  ///
  /// Idempotente por construção: a penalidade da regra é ACUMULADA, então o
  /// que falta cobrar é a diferença entre o que o total de hoje manda e o que
  /// já foi cobrado. Reavaliar sem uso novo dá exatamente zero.
  Future<int> avaliar() async {
    if (_avaliando) return 0;
    _avaliando = true;

    try {
      final medicao = await medir();
      _permissaoConcedida = medicao.permissaoConcedida;

      if (!medicao.permissaoConcedida) {
        // RF04, item 6: não penaliza e não grava nada.
        _minutosHoje = 0;
        notifyListeners();
        return 0;
      }

      _minutosHoje = medicao.minutos;

      final agora = _relogio();
      // Virada de dia: o contador do dia anterior não vale mais.
      final anterior = (_avaliacao != null && _avaliacao!.ehDoMesmoDia(agora))
          ? _avaliacao!
          : AvaliacaoUsoDiaria.zerada(agora);

      final devida = RegrasEnergia.penalidadeAcumulada(medicao.minutos);
      final jaCobrada =
          RegrasEnergia.penalidadeAcumulada(anterior.minutosContabilizados);
      final delta = devida - jaCobrada;

      // delta > 0 significaria devolver energia — acontece se os minutos
      // caírem (mudança de fuso, ajuste de relógio). Nunca devolvemos.
      final deltaAplicavel = delta < 0 ? delta : 0;

      final novaAvaliacao = anterior.comMinutos(
        medicao.minutos > anterior.minutosContabilizados
            ? medicao.minutos
            : anterior.minutosContabilizados,
      );

      // Só grava se algo mudou de fato. A avaliação dispara em todo resume;
      // sem esta guarda, abrir e fechar o app faria uma escrita em disco por
      // vez sem nenhum dado novo.
      final mudou = anterior.dia != novaAvaliacao.dia ||
          anterior.minutosContabilizados !=
              novaAvaliacao.minutosContabilizados;

      _avaliacao = novaAvaliacao;
      notifyListeners();

      if (mudou) {
        await aoPersistir?.call(novaAvaliacao);
      }

      return deltaAplicavel;
    } finally {
      _avaliando = false;
    }
  }
}
