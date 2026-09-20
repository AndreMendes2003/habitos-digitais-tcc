import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_mascote.dart';
import 'diagnostico_atalho.dart';
import 'tela_casa.dart';
import 'tela_foco.dart';
import 'tela_sequencia.dart';

/// Destinos da barra inferior. A ordem da enum É a ordem na barra e o índice
/// do IndexedStack — uma fonte só, em vez de três listas para manter
/// alinhadas.
enum Aba {
  casa('Casa', Icons.home_outlined, Icons.home),
  foco('Foco', Icons.timer_outlined, Icons.timer),
  sequencia('Sequência', Icons.local_fire_department_outlined,
      Icons.local_fire_department);

  const Aba(this.rotulo, this.icone, this.iconeSelecionado);

  final String rotulo;
  final IconData icone;
  final IconData iconeSelecionado;
}

/// Casca de navegação: barra inferior de três abas sobre um único [EstadoApp].
///
/// DONA DO CICLO DE VIDA (RNF01). O observer subiu da TelaFoco para cá porque
/// a detecção de saída do app não pode depender de qual aba está aberta — com
/// ele numa aba, sair do app com a Sequência à frente não encerraria a
/// sessão em andamento.
///
/// Trocar de aba NÃO é sair do app: é mudança de estado do Flutter e não
/// emite AppLifecycleState nenhum, então não passa nem perto do
/// ControladorSessao. O contador continua correndo porque quem conta é o
/// EstadoApp, acima do MaterialApp, e não a tela.
class CascaApp extends StatefulWidget {
  const CascaApp({super.key});

  @override
  State<CascaApp> createState() => _CascaAppState();
}

class _CascaAppState extends State<CascaApp> with WidgetsBindingObserver {
  /// Índice da aba visível. setState local e puramente visual: não é estado
  /// de domínio e não tem por que subir para o EstadoApp.
  late Aba _aba;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Abrir o app com uma sessão correndo e mostrar outra aba esconderia
    // justamente o que está acontecendo.
    _aba = context.read<EstadoApp>().sessaoEmAndamento ? Aba.foco : Aba.casa;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// RNF01: única ponte entre o ciclo de vida do Android e o domínio.
  /// O critério de qual estado conta como saída mora no ControladorSessao.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<EstadoApp>().aoMudarCicloDeVida(state);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_aba.rotulo),
        actions: const [AtalhoDiagnostico()],
      ),
      // IndexedStack, e não o filho selecionado direto: as três abas seguem
      // montadas, então voltar para uma preserva a rolagem em vez de
      // reconstruí-la do zero.
      body: IndexedStack(
        index: _aba.index,
        children: const [TelaCasa(), TelaFoco(), TelaSequencia()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba.index,
        onDestinationSelected: (indice) =>
            setState(() => _aba = Aba.values[indice]),
        destinations: [
          for (final aba in Aba.values)
            NavigationDestination(
              icon: Icon(aba.icone),
              selectedIcon: Icon(aba.iconeSelecionado),
              label: aba.rotulo,
            ),
        ],
      ),
    );
  }
}
