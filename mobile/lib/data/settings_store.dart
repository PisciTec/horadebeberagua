import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

/// Persistência das configurações (substitui o localStorage do PWA, mesmas chaves).
class SettingsStore {
  static const _kGoal = 'dailyGoal';
  static const _kEnabled = 'alarmsEnabled';
  static const _kStart = 'alarmStart';
  static const _kEnd = 'alarmEnd';
  static const _kInterval = 'alarmInterval';

  // Estado interno do alarme
  static const _kScheduled = 'scheduledAlarms'; // lista de epoch ms agendados
  static const _kLastHandled = 'lastHandledAlarm'; // epoch ms do último alarme atendido
  static const _kVoicePath = 'voiceAlarmPath';
  static const _kVoiceSoundName = 'voiceAlarmSoundName'; // nome do arquivo em Library/Sounds (iOS)

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AppSettings load() {
    const d = AppSettings();
    return AppSettings(
      dailyGoal: _prefs.getInt(_kGoal) ?? d.dailyGoal,
      alarmsEnabled: _prefs.getBool(_kEnabled) ?? d.alarmsEnabled,
      alarmStart: _parse(_prefs.getString(_kStart)) ?? d.alarmStart,
      alarmEnd: _parse(_prefs.getString(_kEnd)) ?? d.alarmEnd,
      alarmInterval: _prefs.getInt(_kInterval) ?? d.alarmInterval,
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setInt(_kGoal, s.dailyGoal);
    await _prefs.setBool(_kEnabled, s.alarmsEnabled);
    await _prefs.setString(_kStart, s.alarmStart.toString());
    await _prefs.setString(_kEnd, s.alarmEnd.toString());
    await _prefs.setInt(_kInterval, s.alarmInterval);
  }

  List<DateTime> get scheduledAlarms => (_prefs.getStringList(_kScheduled) ?? [])
      .map((e) => DateTime.fromMillisecondsSinceEpoch(int.parse(e)))
      .toList();

  Future<void> setScheduledAlarms(List<DateTime> times) => _prefs.setStringList(
      _kScheduled, times.map((t) => t.millisecondsSinceEpoch.toString()).toList());

  DateTime? get lastHandledAlarm {
    final v = _prefs.getInt(_kLastHandled);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  Future<void> setLastHandledAlarm(DateTime t) =>
      _prefs.setInt(_kLastHandled, t.millisecondsSinceEpoch);

  String? get voicePath => _prefs.getString(_kVoicePath);
  String? get voiceSoundName => _prefs.getString(_kVoiceSoundName);

  Future<void> setVoice({String? path, String? soundName}) async {
    if (path == null) {
      await _prefs.remove(_kVoicePath);
    } else {
      await _prefs.setString(_kVoicePath, path);
    }
    if (soundName == null) {
      await _prefs.remove(_kVoiceSoundName);
    } else {
      await _prefs.setString(_kVoiceSoundName, soundName);
    }
  }

  static ClockTime? _parse(String? s) {
    if (s == null) return null;
    try {
      return ClockTime.parse(s);
    } catch (_) {
      return null;
    }
  }
}
