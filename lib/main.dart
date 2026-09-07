import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'dados/repositorio_mascote.dart';
import 'dados/repositorio_sessoes.dart';
import 'dados/repositorio_uso.dart';
import 'ui/tela_foco.dart';
import 'uso/medicao_uso.dart';
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

  runApp(
    AppHabitosDigitais(
      repositorioMascote: RepositorioMascote(caixaMascote),
      repositorioSessoes: RepositorioSessoes(caixaSessoes),
      repositorioUso: RepositorioUso(caixaUso),
      medirUso: ServicoUso().medirHoje,
    ),
  );
}

class AppHabitosDigitais extends StatelessWidget {
  const AppHabitosDigitais({
    required this.repositorioMascote,
    required this.repositorioSessoes,
    required this.repositorioUso,
    required this.medirUso,
    super.key,
  });

  final RepositorioMascote repositorioMascote;
  final RepositorioSessoes repositorioSessoes;
  final RepositorioUso repositorioUso;
  final Future<MedicaoUso> Function() medirUso;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habitos Digitais',
      theme: ThemeData(useMaterial3: true),
      home: TelaFoco(
        repositorioMascote: repositorioMascote,
        repositorioSessoes: repositorioSessoes,
        repositorioUso: repositorioUso,
        medirUso: medirUso,
      ),
    );
  }
}
