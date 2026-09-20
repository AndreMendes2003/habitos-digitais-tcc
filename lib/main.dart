import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'dados/repositorio_baseline.dart';
import 'dados/repositorio_historico.dart';
import 'dados/repositorio_mascote.dart';
import 'dados/repositorio_sessoes.dart';
import 'dados/repositorio_uso.dart';
import 'dominio/captura_baseline.dart';
import 'estado/estado_mascote.dart';
import 'ui/componentes/animacoes_mascote.dart';
import 'ui/tema/tema.dart';
import 'ui/casca_app.dart';
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
  final caixaBaseline = await Hive.openBox<Map<dynamic, dynamic>>(
    RepositorioBaseline.nomeCaixa,
  );

  // As tres composicoes Lottie somam ~1,1MB de JSON. Decodificadas aqui, uma
  // vez, e nao na troca de estado — que acontece logo depois de o usuario
  // concluir ou interromper uma sessao, quando a tela precisa responder.
  await AnimacoesMascote.precarregar();

  // Uma instância só: `medirHoje` e `medirDia` compartilham o mesmo núcleo,
  // e é isso que garante que baseline e intervenção sejam comparáveis.
  final servicoUso = ServicoUso();
  final repositorioHistorico = RepositorioHistorico(caixaHistorico);

  runApp(
    // Acima do MaterialApp de propósito: o EstadoApp sobrevive a qualquer
    // navegação, e o gatilho de abertura a frio do RF04 dispara uma vez só,
    // na criação, e não a cada vez que a tela é remontada.
    ChangeNotifierProvider<EstadoApp>(
      create: (_) => EstadoApp(
        repositorioMascote: RepositorioMascote(caixaMascote),
        repositorioSessoes: RepositorioSessoes(caixaSessoes),
        repositorioUso: RepositorioUso(caixaUso),
        repositorioHistorico: repositorioHistorico,
        medirUso: servicoUso.medirHoje,
        capturaBaseline: CapturaBaseline(
          medirDia: servicoUso.medirDia,
          repositorioHistorico: repositorioHistorico,
          repositorioBaseline: RepositorioBaseline(caixaBaseline),
        ),
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
      theme: Tema.claro,
      darkTheme: Tema.escuro,
      // Sem parâmetros: a casca e as tres abas leem o EstadoApp
      // registrado acima.
      home: const CascaApp(),
    );
  }
}
