import '../models/settings.dart';

/// Calcula os próximos horários de lembrete dentro da janela diária.
///
/// Mesma regra do `calculateNextAlarm()` do PWA: os alarmes começam no horário
/// de início e se repetem a cada [interval] minutos até o horário de fim
/// (inclusive). Depois do fim, o próximo é o início do dia seguinte.
///
/// Extensão: se o fim for menor ou igual ao início (ex.: 22:00 → 02:00), a
/// janela atravessa a meia-noite.
///
/// O iOS só permite 64 notificações pendentes por app, por isso o padrão é
/// devolver no máximo [maxCount] horários; o app reagenda ao ser aberto.
List<DateTime> upcomingAlarms({
  required DateTime now,
  required ClockTime start,
  required ClockTime end,
  required int interval,
  int maxCount = 60,
  int maxDays = 14,
}) {
  assert(interval > 0);
  final result = <DateTime>[];
  final crossesMidnight = end.totalMinutes <= start.totalMinutes;

  // Começa em "ontem" para cobrir janelas que atravessam a meia-noite.
  for (var dayOffset = -1; dayOffset <= maxDays && result.length < maxCount; dayOffset++) {
    final windowStart =
        DateTime(now.year, now.month, now.day + dayOffset, start.hour, start.minute);
    final windowEnd = DateTime(now.year, now.month,
        now.day + dayOffset + (crossesMidnight ? 1 : 0), end.hour, end.minute);

    var t = windowStart;
    var step = 0;
    while (!t.isAfter(windowEnd) && result.length < maxCount) {
      if (t.isAfter(now)) result.add(t);
      step++;
      // Recalcula a partir do início (evita acumular desvio em trocas de horário de verão)
      t = DateTime(windowStart.year, windowStart.month, windowStart.day, windowStart.hour,
          windowStart.minute + interval * step);
    }
  }
  return result;
}

/// O alarme mais recente que já deveria ter tocado e ainda não foi atendido.
/// Usado quando o app volta ao primeiro plano (ou é aberto pela notificação)
/// para exibir a tela cheia do alarme.
DateTime? dueAlarm({
  required DateTime now,
  required List<DateTime> scheduled,
  DateTime? lastHandled,
  Duration tolerance = const Duration(minutes: 5),
}) {
  DateTime? latest;
  for (final t in scheduled) {
    if (t.isAfter(now)) continue;
    if (now.difference(t) > tolerance) continue;
    if (lastHandled != null && !t.isAfter(lastHandled)) continue;
    if (latest == null || t.isAfter(latest)) latest = t;
  }
  return latest;
}
