/// Formatação de duração e data, compartilhada pelas telas.
///
/// Extraído da TelaFoco quando ela virou três telas: o cronômetro vive na
/// aba Foco e o histórico na aba Sequência, e as duas precisam do mesmo
/// `mm:ss`. Duas cópias divergiriam no primeiro ajuste.
library;

import 'package:intl/intl.dart';

/// Padrão todo numérico: não depende de dados de locale, então dispensa
/// `initializeDateFormatting()`.
final DateFormat formatoInicio = DateFormat('dd/MM/yyyy HH:mm');

String formatarDuracao(Duration d) {
  final minutos = d.inMinutes.toString().padLeft(2, '0');
  final segundos = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutos:$segundos';
}
