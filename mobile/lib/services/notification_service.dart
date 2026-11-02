import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Lembretes agendados no sistema operacional — tocam mesmo com o app fechado
/// (no PWA o alarme era um setInterval que só funcionava com a página aberta).
///
/// Android: notificação de categoria "alarme" com *full-screen intent*: com a
/// tela bloqueada/apagada o app abre por cima de tudo direto na tela do alarme.
/// iOS: notificação com a voz gravada como som (máx. 30 s); ao tocar nela o
/// app abre na tela do alarme.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'aquavoice_alarm_v1';
  static const _channelName = 'Lembretes de água';
  static const _baseId = 1000;

  /// Chamado quando o usuário toca na notificação (payload = epoch ms do alarme).
  void Function(DateTime alarmTime)? onAlarmOpened;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  /// Inicializa e devolve o horário do alarme se o app foi aberto pela notificação.
  Future<DateTime?> init() async {
    tzdata.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) {
        final t = _parsePayload(resp.payload);
        if (t != null) onAlarmOpened?.call(t);
      },
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      return _parsePayload(launch!.notificationResponse?.payload);
    }
    return null;
  }

  /// Pede as permissões necessárias. Retorna true se as notificações foram liberadas.
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      return await _ios?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
    }
    final android = _android;
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission() ?? false;
    // Android 12+: alarmes exatos (no Android 14+ vem negado por padrão).
    if (!(await android.canScheduleExactNotifications() ?? true)) {
      await android.requestExactAlarmsPermission();
    }
    return granted;
  }

  /// Android 14+: abre a tela de configuração para permitir a tela cheia sobre outros apps.
  Future<void> requestFullScreenPermission() async {
    await _android?.requestFullScreenIntentPermission();
  }

  /// Cancela tudo e agenda os horários informados.
  /// [iosSoundName]: arquivo em Library/Sounds (voz gravada) ou null para o som padrão do app.
  Future<void> scheduleAll(List<DateTime> times, {String? iosSoundName}) async {
    await _plugin.cancelAll();
    if (times.isEmpty) return;

    final exact = Platform.isAndroid
        ? (await _android?.canScheduleExactNotifications() ?? false)
        : true;
    final mode =
        exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Alarmes para lembrar de beber água',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('chime'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
        // FLAG_INSISTENT: o som repete até a notificação ser aberta/dispensada
        additionalFlags: Int32List.fromList([4]),
        ticker: 'Hora de beber água!',
        visibility: NotificationVisibility.public,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        sound: iosSoundName ?? 'chime.wav',
        interruptionLevel: InterruptionLevel.active,
      ),
    );

    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      try {
        await _plugin.zonedSchedule(
          _baseId + i,
          'Hora de beber água! 💧',
          'Seu corpo precisa de hidratação. Toque para abrir o lembrete.',
          tz.TZDateTime.from(t, tz.UTC),
          details,
          androidScheduleMode: mode,
          payload: t.millisecondsSinceEpoch.toString(),
        );
      } catch (e) {
        debugPrint('Falha ao agendar lembrete $t: $e');
      }
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Remove da bandeja as notificações já disparadas (para o som insistente).
  Future<void> dismissDelivered() async {
    final active = await _plugin.getActiveNotifications();
    for (final n in active) {
      if (n.id != null) await _plugin.cancel(n.id!);
    }
  }

  static DateTime? _parsePayload(String? payload) {
    final ms = int.tryParse(payload ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
