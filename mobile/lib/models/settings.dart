/// Hora do dia (HH:mm) sem depender do Material TimeOfDay — facilita testes.
class ClockTime {
  final int hour;
  final int minute;
  const ClockTime(this.hour, this.minute);

  factory ClockTime.parse(String s) {
    final parts = s.split(':');
    return ClockTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  int get totalMinutes => hour * 60 + minute;

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => totalMinutes;
}

/// Configurações do usuário (mesmas chaves/valores padrão do localStorage do PWA).
class AppSettings {
  final int dailyGoal; // ml
  final bool alarmsEnabled;
  final ClockTime alarmStart;
  final ClockTime alarmEnd;
  final int alarmInterval; // minutos

  const AppSettings({
    this.dailyGoal = 2000,
    this.alarmsEnabled = false,
    this.alarmStart = const ClockTime(8, 0),
    this.alarmEnd = const ClockTime(22, 0),
    this.alarmInterval = 60,
  });

  static const minGoal = 500;
  static const maxGoal = 10000;
  static const minInterval = 5;
  static const maxInterval = 360;

  AppSettings copyWith({
    int? dailyGoal,
    bool? alarmsEnabled,
    ClockTime? alarmStart,
    ClockTime? alarmEnd,
    int? alarmInterval,
  }) =>
      AppSettings(
        dailyGoal: (dailyGoal ?? this.dailyGoal).clamp(minGoal, maxGoal).toInt(),
        alarmsEnabled: alarmsEnabled ?? this.alarmsEnabled,
        alarmStart: alarmStart ?? this.alarmStart,
        alarmEnd: alarmEnd ?? this.alarmEnd,
        alarmInterval: (alarmInterval ?? this.alarmInterval).clamp(minInterval, maxInterval).toInt(),
      );
}
