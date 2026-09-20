import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dominio/calculo_sequencia.dart';
import '../estado/estado_mascote.dart';
import 'formato_duracao.dart';
import 'tema/cores.dart';
import 'tema/espacamento.dart';
import 'tema/tipografia.dart';

/// Aba Sequência (RF07): dias consecutivos dentro do limite, a grade dos
/// últimos 30 dias e o histórico de sessões.
///
/// NADA É CALCULADO AQUI. `sequenciaAtual`, `maiorSequencia` e
/// `gradeUltimos30Dias` vêm prontos do EstadoApp, que por sua vez delega ao
/// CalculoSequencia. Recontar a sequência na tela abriria a porta para a UI
/// e o domínio discordarem sobre o que é uma lacuna.
class TelaSequencia extends StatelessWidget {
  const TelaSequencia({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoApp>();
    final grade = estado.gradeUltimos30Dias;
    final semHistorico = grade.every((dia) => dia.registro == null);

    return ListView(
      padding: const EdgeInsets.all(Espacamento.lg),
      children: [
        _Cabecalho(
          atual: estado.sequenciaAtual,
          recorde: estado.maiorSequencia,
          primeiroDia: semHistorico,
        ),
        const SizedBox(height: Espacamento.xl),
        _Grade(dias: grade),
        const SizedBox(height: Espacamento.lg),
        const _Legenda(),
        const Divider(height: Espacamento.xxl),
        _Historico(estado: estado),
      ],
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.atual,
    required this.recorde,
    required this.primeiroDia,
  });

  final int atual;
  final int recorde;

  /// Nenhum dia registrado ainda. Zerado aqui não é fracasso — é começo, e a
  /// tela não pode parecer um erro no primeiro uso.
  final bool primeiroDia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    if (primeiroDia) {
      return Column(
        children: [
          Icon(Icons.local_fire_department,
              size: 40, color: tema.disabledColor),
          const SizedBox(height: Espacamento.sm),
          Text(
            'Sua sequência começa hoje',
            textAlign: TextAlign.center,
            style: Tipografia.titulo.copyWith(color: tema.colorScheme.primary),
          ),
          const SizedBox(height: Espacamento.xs),
          Text(
            'Cada dia dentro do limite de uso entra na conta.',
            textAlign: TextAlign.center,
            style: Tipografia.micro.copyWith(color: tema.disabledColor),
          ),
        ],
      );
    }

    // Chama acesa só quando há sequência: um ícone vivo com "0" ao lado diria
    // a coisa errada.
    final corChama = atual > 0 ? Cores.alerta : tema.disabledColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.local_fire_department, size: 44, color: corChama),
        const SizedBox(width: Espacamento.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$atual', style: Tipografia.display),
            Text(
              atual == 1 ? 'dia seguido' : 'dias seguidos',
              style: Tipografia.micro.copyWith(color: tema.disabledColor),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Recorde', style: Tipografia.micro.copyWith(
              color: tema.disabledColor,
            )),
            Text('$recorde', style: Tipografia.titulo),
          ],
        ),
      ],
    );
  }
}

class _Grade extends StatelessWidget {
  const _Grade({required this.dias});

  final List<DiaDaSequencia> dias;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final hoje = DateTime.now();

    return GridView.count(
      // Dentro da rolagem da página: a grade tem 30 células fixas e não
      // precisa de scroll próprio disputando o gesto.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 10,
      mainAxisSpacing: Espacamento.xs,
      crossAxisSpacing: Espacamento.xs,
      children: [
        for (final dia in dias)
          _Celula(dia: dia, ehHoje: dia.ehHoje(hoje), tema: tema),
      ],
    );
  }
}

class _Celula extends StatelessWidget {
  const _Celula({
    required this.dia,
    required this.ehHoje,
    required this.tema,
  });

  final DiaDaSequencia dia;
  final bool ehHoje;
  final ThemeData tema;

  @override
  Widget build(BuildContext context) {
    final cor = corDoDia(dia, tema);

    return Tooltip(
      message: _descricao(),
      child: Container(
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(Espacamento.xs),
          // O dia corrente é marcado por borda, e não por outra cor: ele já
          // tem uma das três cores e precisa continuar legível como tal.
          border: ehHoje
              ? Border.all(color: tema.colorScheme.onSurface, width: 2)
              : null,
        ),
      ),
    );
  }

  String _descricao() {
    final data = formatoData.format(dia.dia);
    if (dia.cumprido) return '$data — dentro do limite';
    if (dia.falhou) return '$data — acima do limite';
    return '$data — sem medição';
  }
}

/// Cor de uma célula. Fora das classes para a legenda usar exatamente a mesma
/// regra — legenda que diverge da grade é pior que legenda nenhuma.
Color corDoDia(DiaDaSequencia dia, ThemeData tema) {
  if (dia.cumprido) return Cores.feliz;
  if (dia.falhou) return Cores.alerta;
  // Cinza neutro, e não `cansado`: lacuna não é um estado do mascote, é
  // ausência de dado.
  return tema.disabledColor.withValues(alpha: 0.25);
}

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Wrap(
      spacing: Espacamento.lg,
      runSpacing: Espacamento.sm,
      children: [
        _item(tema, Cores.feliz, 'Dentro do limite'),
        _item(tema, Cores.alerta, 'Acima do limite'),
        _item(tema, tema.disabledColor.withValues(alpha: 0.25), 'Sem medição'),
      ],
    );
  }

  Widget _item(ThemeData tema, Color cor, String rotulo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: Espacamento.xs),
        Text(
          rotulo,
          style: Tipografia.micro.copyWith(color: tema.disabledColor),
        ),
      ],
    );
  }
}

class _Historico extends StatelessWidget {
  const _Historico({required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    if (estado.historico.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Espacamento.lg),
        child: Text(
          'Nenhuma sessão registrada ainda.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).disabledColor),
        ),
      );
    }

    /// Já da sessão mais recente para a mais antiga (RepositorioSessoes).
    return Column(
      children: [
        for (final s in estado.historico)
          ListTile(
            dense: true,
            leading: Icon(
              s.foiConcluida ? Icons.check_circle : Icons.cancel,
              color: s.foiConcluida ? Cores.feliz : Cores.cansado,
            ),
            title: Text('${s.duracaoAlvo.inMinutes} min — ${s.status.rotulo}'),
            subtitle: Text('real: ${formatarDuracao(s.duracaoReal)}'),
          ),
      ],
    );
  }
}
