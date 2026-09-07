import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_digitais/ui/tela_foco.dart';

void main() {
  testWidgets('mostra seletor de duracao e botao inicial', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TelaFoco()));

    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    expect(find.text('Iniciar foco'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
  });

  testWidgets('RNF01: so o paused encerra a sessao como INTERROMPIDA',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TelaFoco()));

    await tester.tap(find.text('5 min'));
    await tester.pump();
    await tester.tap(find.text('Iniciar foco'));
    await tester.pump();

    expect(find.text('Em foco — não saia do app'), findsOneWidget);

    // Puxar a barra de notificacao emite `inactive` sem tirar o app do
    // primeiro plano: a sessao tem que sobreviver a isso.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Em foco — não saia do app'), findsOneWidget);
    expect(find.text('INTERROMPIDA'), findsNothing);

    // Saida de verdade. De `hidden` em diante o binding desabilita frames
    // (SchedulerBinding._setFramesEnabledState), entao a arvore so repinta
    // quando o app volta — que e tambem o que acontece no device: o usuario
    // retorna e ai ve o resultado. Por isso as assercoes vem depois do
    // caminho de volta ate `resumed`.
    // O `paused` cancela o Timer da sessao, entao nao sobra timer pendente.
    for (final estado in [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(estado);
      await tester.pump();
    }

    expect(find.text('INTERROMPIDA'), findsWidgets);
    expect(find.text('Nova sessão'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Início: \d{2}/\d{2}/\d{4} \d{2}:\d{2}$')),
      findsOneWidget,
    );
  });
}
