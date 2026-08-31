import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Usage Stats Diagnostico',
      home: const DiagnosticScreen(),
    );
  }
}

class _AppUsage {
  _AppUsage(this.packageName, this.minutes);

  final String packageName;
  final int minutes;
}

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  String _permissionResult = 'Nao verificado';
  List<_AppUsage> _usageList = [];

  Future<void> _checkPermission() async {
    final granted = await UsageStats.checkUsagePermission();
    setState(() {
      _permissionResult = 'Permissao concedida: $granted';
    });
  }

  Future<void> _grantPermission() async {
    await UsageStats.grantUsagePermission();
  }

  Future<void> _queryUsageStats() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(hours: 24));
    final usageList = await UsageStats.queryUsageStats(startDate, endDate);

    final entries = usageList
        .map((usage) {
          final ms = int.tryParse(usage.totalTimeInForeground ?? '0') ?? 0;
          return _AppUsage(usage.packageName ?? 'desconhecido', ms ~/ 60000);
        })
        .where((entry) => entry.minutes > 0)
        .toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    setState(() {
      _usageList = entries;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostico Usage Stats')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _checkPermission,
              child: const Text('Checar permissao'),
            ),
            const SizedBox(height: 8),
            Text(_permissionResult),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _grantPermission,
              child: const Text('Abrir configuracoes de permissao'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _queryUsageStats,
              child: const Text('Consultar uso (ultimas 24h)'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _usageList.length,
                itemBuilder: (context, index) {
                  final entry = _usageList[index];
                  return ListTile(
                    title: Text(entry.packageName),
                    trailing: Text('${entry.minutes} min'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
