import '../models/water_record.dart';

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Total de ml por dia (chave = meia-noite local do dia).
Map<DateTime, int> totalsByDay(Iterable<WaterRecord> records) {
  final map = <DateTime, int>{};
  for (final r in records) {
    final d = dayOf(r.timestamp);
    map[d] = (map[d] ?? 0) + r.amount;
  }
  return map;
}

/// Totais de segunda a domingo da semana atual (índice 0 = segunda).
/// Mesma regra do `updateWeeklyChartUI()` do PWA.
List<int> weekTotals(Map<DateTime, int> totals, DateTime now) {
  final monday = dayOf(now).subtract(Duration(days: now.weekday - DateTime.monday));
  return List.generate(7, (i) {
    final d = DateTime(monday.year, monday.month, monday.day + i);
    return totals[d] ?? 0;
  });
}

/// Dias seguidos batendo a meta. Começa em hoje se a meta de hoje já foi
/// batida; senão conta a partir de ontem (o dia de hoje ainda está em aberto).
/// Mesma regra do `calculateStreak()` do PWA.
int streak(Map<DateTime, int> totals, int goal, DateTime now) {
  var day = dayOf(now);
  if ((totals[day] ?? 0) < goal) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var count = 0;
  while ((totals[day] ?? 0) >= goal) {
    count++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return count;
}

/// Percentual (0–100) da meta.
int percentOf(int total, int goal) =>
    goal <= 0 ? 0 : ((total / goal) * 100).round().clamp(0, 100).toInt();
