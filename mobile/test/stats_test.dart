import 'package:aquavoice/models/water_record.dart';
import 'package:aquavoice/utils/stats.dart';
import 'package:flutter_test/flutter_test.dart';

WaterRecord rec(DateTime t, int ml) => WaterRecord(timestamp: t, amount: ml, type: 'Copo');

void main() {
  // Quarta-feira
  final now = DateTime(2026, 11, 4, 15, 0);

  test('totalsByDay soma por dia local', () {
    final t = totalsByDay([
      rec(DateTime(2026, 11, 4, 8), 200),
      rec(DateTime(2026, 11, 4, 23, 59), 300),
      rec(DateTime(2026, 11, 5, 0, 1), 500),
    ]);
    expect(t[DateTime(2026, 11, 4)], 500);
    expect(t[DateTime(2026, 11, 5)], 500);
  });

  test('weekTotals vai de segunda a domingo', () {
    final t = totalsByDay([
      rec(DateTime(2026, 11, 2, 9), 1000), // segunda
      rec(DateTime(2026, 11, 4, 9), 700), // quarta
      rec(DateTime(2026, 11, 8, 9), 300), // domingo
      rec(DateTime(2026, 11, 1, 9), 999), // domingo anterior (fora)
    ]);
    expect(weekTotals(t, now), [1000, 0, 700, 0, 0, 0, 300]);
  });

  test('weekTotals no domingo considera a semana que começou na segunda', () {
    final sunday = DateTime(2026, 11, 8, 10);
    final t = totalsByDay([rec(DateTime(2026, 11, 2, 9), 100)]);
    expect(weekTotals(t, sunday).first, 100);
  });

  group('streak', () {
    test('conta a partir de hoje quando a meta de hoje foi batida', () {
      final t = totalsByDay([
        rec(DateTime(2026, 11, 4, 9), 2000),
        rec(DateTime(2026, 11, 3, 9), 2000),
        rec(DateTime(2026, 11, 1, 9), 2000), // buraco no dia 2
      ]);
      expect(streak(t, 2000, now), 2);
    });

    test('hoje em aberto não quebra a sequência', () {
      final t = totalsByDay([
        rec(DateTime(2026, 11, 4, 9), 500),
        rec(DateTime(2026, 11, 3, 9), 2500),
        rec(DateTime(2026, 11, 2, 9), 2000),
      ]);
      expect(streak(t, 2000, now), 2);
    });

    test('zero quando ontem não bateu a meta', () {
      final t = totalsByDay([rec(DateTime(2026, 11, 2, 9), 3000)]);
      expect(streak(t, 2000, now), 0);
    });
  });

  test('percentOf limita a 100%', () {
    expect(percentOf(1000, 2000), 50);
    expect(percentOf(5000, 2000), 100);
    expect(percentOf(0, 2000), 0);
  });
}
