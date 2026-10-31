import 'package:aquavoice/models/settings.dart';
import 'package:aquavoice/utils/alarm_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const start = ClockTime(8, 0);
  const end = ClockTime(22, 0);

  group('upcomingAlarms', () {
    test('antes do início: primeiro alarme é o início de hoje', () {
      final now = DateTime(2026, 11, 2, 6, 30);
      final r = upcomingAlarms(now: now, start: start, end: end, interval: 60);
      expect(r.first, DateTime(2026, 11, 2, 8, 0));
      expect(r[1], DateTime(2026, 11, 2, 9, 0));
    });

    test('no meio do dia: próximo múltiplo do intervalo a partir do início', () {
      final now = DateTime(2026, 11, 2, 10, 15);
      final r = upcomingAlarms(now: now, start: start, end: end, interval: 45);
      // 8:00, 8:45, 9:30, 10:15 (não conta, é agora), 11:00
      expect(r.first, DateTime(2026, 11, 2, 11, 0));
    });

    test('o horário de fim é inclusivo', () {
      final now = DateTime(2026, 11, 2, 21, 30);
      final r = upcomingAlarms(now: now, start: start, end: end, interval: 60);
      expect(r.first, DateTime(2026, 11, 2, 22, 0));
      expect(r[1], DateTime(2026, 11, 3, 8, 0));
    });

    test('depois do fim: próximo é o início de amanhã', () {
      final now = DateTime(2026, 11, 2, 22, 30);
      final r = upcomingAlarms(now: now, start: start, end: end, interval: 60);
      expect(r.first, DateTime(2026, 11, 3, 8, 0));
    });

    test('respeita o limite de notificações', () {
      final now = DateTime(2026, 11, 2, 0, 0);
      final r = upcomingAlarms(now: now, start: start, end: end, interval: 5, maxCount: 60);
      expect(r.length, 60);
      expect(r.every((t) => t.isAfter(now)), isTrue);
    });

    test('janela que atravessa a meia-noite', () {
      final now = DateTime(2026, 11, 2, 23, 10);
      final r = upcomingAlarms(
          now: now, start: const ClockTime(22, 0), end: const ClockTime(1, 0), interval: 30);
      expect(r.take(4), [
        DateTime(2026, 11, 2, 23, 30),
        DateTime(2026, 11, 3, 0, 0),
        DateTime(2026, 11, 3, 0, 30),
        DateTime(2026, 11, 3, 1, 0),
      ]);
      expect(r[4], DateTime(2026, 11, 3, 22, 0));
    });

    test('resultado é crescente e sem repetição', () {
      final now = DateTime(2026, 11, 2, 12, 7);
      final r = upcomingAlarms(now: now, start: start, end: end, interval: 25);
      for (var i = 1; i < r.length; i++) {
        expect(r[i].isAfter(r[i - 1]), isTrue);
      }
    });
  });

  group('dueAlarm', () {
    final scheduled = [
      DateTime(2026, 11, 2, 8, 0),
      DateTime(2026, 11, 2, 9, 0),
      DateTime(2026, 11, 2, 10, 0),
    ];

    test('retorna o alarme que acabou de tocar', () {
      final r = dueAlarm(now: DateTime(2026, 11, 2, 9, 2), scheduled: scheduled);
      expect(r, DateTime(2026, 11, 2, 9, 0));
    });

    test('ignora alarmes antigos (fora da tolerância)', () {
      final r = dueAlarm(now: DateTime(2026, 11, 2, 9, 30), scheduled: scheduled);
      expect(r, isNull);
    });

    test('ignora alarme já atendido', () {
      final r = dueAlarm(
        now: DateTime(2026, 11, 2, 9, 2),
        scheduled: scheduled,
        lastHandled: DateTime(2026, 11, 2, 9, 0),
      );
      expect(r, isNull);
    });
  });
}
