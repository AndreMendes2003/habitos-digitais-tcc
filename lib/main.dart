import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'dados/repositorio_mascote.dart';
import 'dados/repositorio_sessoes.dart';
import 'ui/tela_foco.dart';

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

  runApp(
    AppHabitosDigitais(
      repositorioMascote: RepositorioMascote(caixaMascote),
      repositorioSessoes: RepositorioSessoes(caixaSessoes),
    ),
  );
}

class AppHabitosDigitais extends StatelessWidget {
  const AppHabitosDigitais({
    required this.repositorioMascote,
    required this.repositorioSessoes,
    super.key,
  });

  final RepositorioMascote repositorioMascote;
  final RepositorioSessoes repositorioSessoes;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habitos Digitais',
      theme: ThemeData(useMaterial3: true),
      home: TelaFoco(
        repositorioMascote: repositorioMascote,
        repositorioSessoes: repositorioSessoes,
      ),
    );
  }
}
