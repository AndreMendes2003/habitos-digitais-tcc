import 'package:flutter/material.dart';

import 'ui/tela_foco.dart';

void main() {
  runApp(const AppHabitosDigitais());
}

class AppHabitosDigitais extends StatelessWidget {
  const AppHabitosDigitais({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habitos Digitais',
      theme: ThemeData(useMaterial3: true),
      home: const TelaFoco(),
    );
  }
}
