/// SPIKE DESCARTÁVEL — F20. Apagar depois de colhida a evidência.
///
/// PERGUNTA QUE ESTE SPIKE RESPONDE: quantos dias de histórico retroativo o
/// UsageStatsManager devolve neste aparelho (Galaxy S23)? A documentação do
/// Android não garante número nenhum — a retenção dos buckets é decisão do
/// fabricante e varia com a ROM. Sem medir, qualquer afirmação sobre "N dias
/// de histórico" no texto do TCC seria chute.
///
/// FORA DO FLUXO DO APP: entrypoint próprio, nada aqui é importado por
/// lib/main.dart. Rodar com
///
///   flutter run -t lib/spikes/spike_retencao_usage.dart
///
/// em device físico. Emulador não gera dados de uso e devolveria zero em
/// todos os dias — o que pareceria "sem retenção" e seria leitura falsa.
///
/// RESSALVA SOBRE O MÉTODO, que precisa ir junto do dado no artigo: aqui se
/// usa `queryUsageStats`, e não o `queryAndAggregateUsageStats` que o
/// ServicoUso usa em produção. O primeiro pode devolver vários buckets do
/// mesmo package dentro da janela (INTERVAL_BEST), e este spike soma esses
/// buckets por package. Se o Android devolver buckets sobrepostos, os minutos
/// saem SUPERESTIMADOS. Para a pergunta deste spike — o dia volta ou não
/// volta? — isso não atrapalha; para comparar minutos com os do RF04, sim.
/// Os minutos aqui são indício de presença de dado, não medida de uso.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:usage_stats/usage_stats.dart';

import '../uso/classificador_redes_sociais.dart';

/// Quantos dias para trás sondar. 44 cobre com folga as semanas do piloto.
const int _diasRetroativos = 44;

/// Nome do arquivo de evidência. O destino final é
/// docs/evidencias/F20_retencao_usage_s23.csv na máquina de desenvolvimento;
/// o app só escreve no armazenamento do próprio aparelho, então o arquivo é
/// gerado lá e puxado por `adb pull` (comando impresso no console).
const String _nomeArquivo = 'F20_retencao_usage_s23.csv';

const String _cabecalhoCsv =
    'data;pacotes_com_uso;minutos_totais;minutos_redes;top3';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppSpike());
}

class _AppSpike extends StatelessWidget {
  const _AppSpike();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spike F20 retencao usage',
      theme: ThemeData(useMaterial3: true),
      home: const _TelaSpike(),
    );
  }
}

/// Uma linha do CSV. `erro` preenchido significa que o dia falhou: os demais
/// campos saem como ERRO e o laço segue — um dia que estoura não pode
/// derrubar a sondagem dos outros.
class _LinhaDia {
  _LinhaDia.ok({
    required this.data,
    required this.pacotesComUso,
    required this.minutosTotais,
    required this.minutosRedes,
    required this.top3,
  }) : erro = null;

  _LinhaDia.erro({required this.data, required String mensagem})
      : pacotesComUso = 0,
        minutosTotais = 0,
        minutosRedes = 0,
        top3 = const [],
        // `;` e quebras de linha arruinariam o CSV: a mensagem vem do plugin
        // e não tem formato garantido.
        erro = mensagem.replaceAll(RegExp(r'[;\r\n]'), ' ');

  final String data;
  final int pacotesComUso;
  final int minutosTotais;
  final int minutosRedes;
  final List<String> top3;
  final String? erro;

  String paraCsv() {
    if (erro != null) return '$data;ERRO;ERRO;ERRO;$erro';
    return '$data;$pacotesComUso;$minutosTotais;$minutosRedes;'
        '${top3.join('|')}';
  }
}

class _TelaSpike extends StatefulWidget {
  const _TelaSpike();

  @override
  State<_TelaSpike> createState() => _TelaSpikeState();
}

class _TelaSpikeState extends State<_TelaSpike> {
  bool _rodando = false;
  String _status = 'Pronto. Confira a permissao antes de rodar.';
  String _caminhoArquivo = '';
  List<String> _linhas = const [];

  Future<void> _checarPermissao() async {
    final permitido = await UsageStats.checkUsagePermission() ?? false;
    if (!mounted) return;
    setState(() {
      _status = permitido
          ? 'Permissao concedida. Pode rodar.'
          : 'SEM permissao. Abra as configuracoes e libere o acesso de uso.';
    });
  }

  Future<void> _abrirConfiguracoes() async {
    await UsageStats.openUsageAccessSettings();
  }

  Future<void> _rodar() async {
    setState(() {
      _rodando = true;
      _status = 'Sondando ${_diasRetroativos + 1} dias...';
      _linhas = const [];
      _caminhoArquivo = '';
    });

    final permitido = await UsageStats.checkUsagePermission() ?? false;
    if (!permitido) {
      // Sem PACKAGE_USAGE_STATS toda consulta volta vazia, sem erro nenhum.
      // Rodar assim produziria 45 dias de zeros — evidência falsa de que o
      // aparelho não guarda histórico. Melhor não gerar arquivo.
      await UsageStats.grantUsagePermission();
      if (!mounted) return;
      setState(() {
        _rodando = false;
        _status = 'SEM permissao: nada foi medido. Libere o acesso e rode de '
            'novo (45 dias de zero nao seriam evidencia de nada).';
      });
      return;
    }

    final linhas = await _coletar();
    final csv = _montarCsv(linhas);
    final caminho = await _salvar(csv);

    debugPrint('[F20] --- inicio do CSV ---');
    for (final linha in csv.split('\n')) {
      debugPrint('[F20] $linha');
    }
    debugPrint('[F20] --- fim do CSV ---');
    debugPrint('[F20] arquivo salvo em: $caminho');
    debugPrint('[F20] para trazer ao repositorio:');
    debugPrint('[F20]   adb pull "$caminho" docs/evidencias/$_nomeArquivo');

    final comDado = linhas
        .where((linha) => linha.erro == null && linha.pacotesComUso > 0)
        .toList();
    final maisAntigo = comDado.isEmpty ? null : comDado.last.data;

    if (!mounted) return;
    setState(() {
      _rodando = false;
      _linhas = linhas.map((linha) => linha.paraCsv()).toList();
      _caminhoArquivo = caminho;
      _status = maisAntigo == null
          ? 'Nenhum dia com dado. Suspeite da permissao antes de concluir.'
          : 'Dias com dado: ${comDado.length}. Mais antigo: $maisAntigo.';
    });
  }

  /// Um dia por iteração, do mais recente para o mais antigo — a ordem
  /// cronológica inversa já sai pronta do laço.
  Future<List<_LinhaDia>> _coletar() async {
    final agora = DateTime.now();
    final linhas = <_LinhaDia>[];

    for (var d = 0; d <= _diasRetroativos; d++) {
      // Aritmética pelo construtor, e não subtract(Duration(days: d)): o
      // construtor normaliza no calendário LOCAL e cai na meia-noite certa
      // mesmo atravessando mudança de horário. Duration é tempo absoluto e
      // erraria a hora num eventual dia de 23h.
      final inicio = DateTime(agora.year, agora.month, agora.day - d);
      final fim = DateTime(agora.year, agora.month, agora.day - d + 1);
      final data = _formatarData(inicio);

      try {
        linhas.add(await _sondarDia(data, inicio, fim));
      } catch (erro) {
        // Por dia, não pelo laço inteiro: o interesse é justamente saber
        // ONDE a consulta começa a falhar.
        debugPrint('[F20] $data FALHOU: $erro');
        linhas.add(_LinhaDia.erro(data: data, mensagem: erro.toString()));
      }
    }

    return linhas;
  }

  Future<_LinhaDia> _sondarDia(
    String data,
    DateTime inicio,
    DateTime fim,
  ) async {
    final registros = await UsageStats.queryUsageStats(inicio, fim);

    // Soma por package: queryUsageStats pode repetir o mesmo package em
    // buckets diferentes dentro da janela (ver ressalva no topo do arquivo).
    final msPorPackage = <String, int>{};
    for (final registro in registros) {
      final package = registro.packageName;
      if (package == null) continue;
      final ms = registro.totalTimeInForegroundMs ?? 0;
      if (ms <= 0) continue;
      msPorPackage.update(package, (atual) => atual + ms, ifAbsent: () => ms);
    }

    var msTotais = 0;
    var msRedes = 0;
    for (final entrada in msPorPackage.entries) {
      msTotais += entrada.value;
      if (ClassificadorRedesSociais.eRedeSocial(entrada.key)) {
        msRedes += entrada.value;
      }
    }

    final ordenados = msPorPackage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = ordenados
        .take(3)
        .map((entrada) => '${entrada.key}=${entrada.value ~/ 60000}min')
        .toList();

    return _LinhaDia.ok(
      data: data,
      pacotesComUso: msPorPackage.length,
      minutosTotais: msTotais ~/ 60000,
      minutosRedes: msRedes ~/ 60000,
      top3: top3,
    );
  }

  String _montarCsv(List<_LinhaDia> linhas) {
    final geradoEm = DateTime.now().toIso8601String();
    return [
      '# F20 - retencao do UsageStatsManager, device fisico (Galaxy S23)',
      '# gerado em: $geradoEm (horario local do aparelho)',
      '# janela por dia: meia-noite local ate meia-noite local seguinte',
      '# fonte: UsageStats.queryUsageStats, buckets somados por package',
      '# minutos = indicio de presenca de dado, nao medida de uso (ver spike)',
      '# redes sociais = ClassificadorRedesSociais.packages do projeto',
      _cabecalhoCsv,
      ...linhas.map((linha) => linha.paraCsv()),
    ].join('\n');
  }

  /// Escreve no armazenamento externo do app — o diretório que o `adb pull`
  /// alcança sem root. Se o aparelho não expuser externo, cai no diretório de
  /// documentos, que ainda sai por `adb exec-out run-as`.
  Future<String> _salvar(String csv) async {
    final diretorio = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final arquivo = File('${diretorio.path}/$_nomeArquivo');
    await arquivo.writeAsString(csv);
    return arquivo.path;
  }

  String _formatarData(DateTime dia) {
    final mes = dia.month.toString().padLeft(2, '0');
    final diaDoMes = dia.day.toString().padLeft(2, '0');
    return '${dia.year}-$mes-$diaDoMes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spike F20 - retencao usage')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _rodando ? null : _checarPermissao,
                    child: const Text('Checar permissao'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _rodando ? null : _abrirConfiguracoes,
                    child: const Text('Configuracoes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _rodando ? null : _rodar,
              child: Text(_rodando ? 'Rodando...' : 'Rodar'),
            ),
            const SizedBox(height: 12),
            Text(_status),
            if (_caminhoArquivo.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                'Arquivo: $_caminhoArquivo',
                style: const TextStyle(fontSize: 11),
              ),
            ],
            const Divider(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _linhas.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: SelectableText(
                    _linhas[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
