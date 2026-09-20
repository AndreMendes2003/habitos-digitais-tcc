import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'dados/repositorio_historico.dart';
import 'dados/repositorio_mascote.dart';
import 'dados/repositorio_sessoes.dart';
import 'dados/repositorio_uso.dart';
import 'estado/estado_mascote.dart';
import 'ui/tela_foco.dart';
import 'uso/servico_uso.dart';

Future<void> main() async {
  // Necessário antes de qualquer plugin: o initFlutter resolve o diretório
  // de dados do app via path_provider.
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Caixas abertas uma vez, no boot. Só primitivos: nenhum TypeAdapter,
  // nenhum build_runner.
  final caixaMascote = await Hive.openBox<int>(RepositorioMascote.nomeCaixa);
  final caixaSessoes = await Hive.openBox<Map<dynamic, dynamic>>(
    RepositorioSessoes.nomeCaixa,
  );
  final caixaUso = await Hive.openBox<Map<dynamic, dynamic>>(
    RepositorioUso.nomeCaixa,
  );
  final caixaHistorico = await Hive.openBox<Map<dynamic, dynamic>>(
    RepositorioHistorico.nomeCaixa,
  );

  runApp(
    // Acima do MaterialApp de propósito: o EstadoApp sobrevive a qualquer
    // navegação, e o gatilho de abertura a frio do RF04 dispara uma vez só,
    // na criação, e não a cada vez que a tela é remontada.
    ChangeNotifierProvider<EstadoApp>(
      create: (_) => EstadoApp(
        repositorioMascote: RepositorioMascote(caixaMascote),
        repositorioSessoes: RepositorioSessoes(caixaSessoes),
        repositorioUso: RepositorioUso(caixaUso),
        repositorioHistorico: RepositorioHistorico(caixaHistorico),
        medirUso: ServicoUso().medirHoje,
      ),
      // Sem `lazy: false` a criação só aconteceria no primeiro `watch`, que
      // vem logo abaixo — mas explicitar deixa o gatilho a frio independente
      // de quem lê primeiro.
      lazy: false,
      child: const AppHabitosDigitais(),
    ),
  );
}

class AppHabitosDigitais extends StatelessWidget {
  const AppHabitosDigitais({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habitos Digitais',
      theme: ThemeData(useMaterial3: true),
      // Sem parâmetros: a tela lê o EstadoApp registrado acima.
      home: const TelaFoco(),
    );
  }
}
