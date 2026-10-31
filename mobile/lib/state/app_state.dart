import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';
import '../data/water_database.dart';
import '../models/settings.dart';
import '../models/water_record.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';
import '../utils/alarm_schedule.dart';
import '../utils/stats.dart' as stats;

/// Estado central do app (equivale ao objeto STATE + funções de refresh do app.js).
class AppState extends ChangeNotifier {
  AppState({
    WaterDatabase? db,
    SettingsStore? store,
  })  : _db = db ?? WaterDatabase(),
        _store = store ?? SettingsStore();

  final WaterDatabase _db;
  final SettingsStore _store;
  final _notifications = NotificationService.instance;
  final _sound = SoundService.instance;

  AppSettings settings = const AppSettings();
  List<WaterRecord> todayLogs = [];
  List<int> weekTotals = List.filled(7, 0);
  int streak = 0;
  DateTime? nextAlarm;
  String? voicePath;

  /// Emite o horário do alarme que deve aparecer em tela cheia.
  final _ringController = StreamController<DateTime>.broadcast();
  Stream<DateTime> get ringRequests => _ringController.stream;

  Timer? _foregroundTicker;

  int get todayTotal => todayLogs.fold(0, (s, r) => s + r.amount);
  int get todayPercent => stats.percentOf(todayTotal, settings.dailyGoal);
  bool get hasVoice => voicePath != null;

  // ---------------------------------------------------------------- init

  Future<void> init() async {
    await _store.init();
    settings = _store.load();
    voicePath = _store.voicePath;
    await _sound.init();

    _notifications.onAlarmOpened = _requestRing;
    final launchedBy = await _notifications.init();

    await refresh();
    await reschedule();

    // Enquanto o app está aberto, confere a cada 15 s se chegou a hora
    // (como o setInterval do PWA) para mostrar a tela cheia imediatamente.
    _foregroundTicker = Timer.periodic(const Duration(seconds: 15), (_) => checkDueAlarm());

    if (launchedBy != null) {
      _requestRing(launchedBy);
    } else {
      checkDueAlarm();
    }
  }

  /// Chamado quando o app volta para o primeiro plano.
  Future<void> onResumed() async {
    await refresh();
    await reschedule(); // repõe a fila de lembretes (limite de 64 no iOS)
    checkDueAlarm();
  }

  // ---------------------------------------------------------------- dados

  Future<void> refresh() async {
    final now = DateTime.now();
    final today = stats.dayOf(now);
    todayLogs = await _db.recordsBetween(today, today.add(const Duration(days: 1)));
    final totals = stats.totalsByDay(await _db.allRecords());
    weekTotals = stats.weekTotals(totals, now);
    streak = stats.streak(totals, settings.dailyGoal, now);
    notifyListeners();
  }

  Future<void> addWater(int amount, String type, {bool feedback = true}) async {
    if (amount <= 0) return;
    await _db.insert(WaterRecord(timestamp: DateTime.now(), amount: amount, type: type));
    if (feedback) _sound.playDrip();
    await refresh();
  }

  Future<void> removeRecord(int id) async {
    await _db.delete(id);
    await refresh();
  }

  Future<void> clearHistory() async {
    await _db.clear();
    await refresh();
  }

  // ---------------------------------------------------------------- configurações

  Future<void> updateSettings(AppSettings next) async {
    final alarmChanged = next.alarmsEnabled != settings.alarmsEnabled ||
        next.alarmStart != settings.alarmStart ||
        next.alarmEnd != settings.alarmEnd ||
        next.alarmInterval != settings.alarmInterval;
    final goalChanged = next.dailyGoal != settings.dailyGoal;
    settings = next;
    await _store.save(settings);
    notifyListeners();
    if (goalChanged) await refresh();
    if (alarmChanged) await reschedule();
  }

  /// Liga/desliga os lembretes pedindo as permissões necessárias.
  /// Retorna false se o usuário negou a permissão de notificação.
  Future<bool> setAlarmsEnabled(bool enabled) async {
    if (enabled) {
      final ok = await _notifications.requestPermissions();
      if (!ok) {
        await updateSettings(settings.copyWith(alarmsEnabled: false));
        return false;
      }
    }
    await updateSettings(settings.copyWith(alarmsEnabled: enabled));
    return true;
  }

  Future<void> requestFullScreenPermission() => _notifications.requestFullScreenPermission();

  // ---------------------------------------------------------------- voz

  Future<void> setVoice({String? path, String? iosSoundName}) async {
    voicePath = path;
    await _store.setVoice(path: path, soundName: iosSoundName);
    notifyListeners();
    await reschedule(); // o som dos lembretes no iOS muda junto
  }

  // ---------------------------------------------------------------- alarmes

  Future<void> reschedule() async {
    if (!settings.alarmsEnabled) {
      nextAlarm = null;
      await _notifications.cancelAll();
      await _store.setScheduledAlarms([]);
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    final times = upcomingAlarms(
      now: now,
      start: settings.alarmStart,
      end: settings.alarmEnd,
      interval: settings.alarmInterval,
    );
    // Mantém também os já passados recentes para o checkDueAlarm encontrá-los.
    final recentPast = _store.scheduledAlarms
        .where((t) => !t.isAfter(now) && now.difference(t) < const Duration(minutes: 10));
    await _store.setScheduledAlarms([...recentPast, ...times]);
    await _notifications.scheduleAll(times, iosSoundName: _store.voiceSoundName);
    nextAlarm = times.isEmpty ? null : times.first;
    notifyListeners();
  }

  void checkDueAlarm() {
    if (!settings.alarmsEnabled) return;
    final due = dueAlarm(
      now: DateTime.now(),
      scheduled: _store.scheduledAlarms,
      lastHandled: _store.lastHandledAlarm,
    );
    if (due != null) _requestRing(due);
  }

  void _requestRing(DateTime alarmTime) {
    final last = _store.lastHandledAlarm;
    if (last != null && !alarmTime.isAfter(last)) return;
    _ringController.add(alarmTime);
  }

  /// O alarme foi atendido. [drank] registra 250 ml como no PWA.
  Future<void> handleAlarm(DateTime alarmTime, {required bool drank}) async {
    await _store.setLastHandledAlarm(alarmTime);
    await _notifications.dismissDelivered();
    if (drank) await addWater(250, 'Lembrete do Alarme', feedback: false);
    await reschedule();
  }

  /// Usado pelo botão "Testar alarme".
  void testRing() => _ringController.add(DateTime.now());

  @override
  void dispose() {
    _foregroundTicker?.cancel();
    _ringController.close();
    super.dispose();
  }
}

/// Disponibiliza o [AppState] para a árvore de widgets.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
