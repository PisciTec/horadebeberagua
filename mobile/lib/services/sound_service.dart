import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Sons do app: "gota" ao registrar água, prévia da voz e o alarme em loop.
class SoundService {
  SoundService._();
  static final instance = SoundService._();

  final _fx = AudioPlayer(playerId: 'fx');
  final _preview = AudioPlayer(playerId: 'preview');
  final _alarm = AudioPlayer(playerId: 'alarm');
  Timer? _vibrationTimer;

  /// Toca mesmo com o iPhone no silencioso e usa o volume de alarme no Android.
  static final _alarmContext = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: const {}),
    android: AudioContextAndroid(
      usageType: AndroidUsageType.alarm,
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
  );

  static final _mediaContext = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
    android: AudioContextAndroid(
      usageType: AndroidUsageType.media,
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  Future<void> init() async {
    await _fx.setAudioContext(_mediaContext);
    await _fx.setPlayerMode(PlayerMode.lowLatency);
    await _alarm.setAudioContext(_alarmContext);
    await _alarm.setReleaseMode(ReleaseMode.loop);
    if (Platform.isIOS) await _installIosChime();
  }

  /// O iOS só usa sons customizados de notificação que estejam no bundle ou
  /// em Library/Sounds. Copiamos o chime para lá na primeira execução.
  Future<void> _installIosChime() async {
    try {
      final lib = await getLibraryDirectory();
      final dir = Directory(p.join(lib.path, 'Sounds'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final target = File(p.join(dir.path, 'chime.wav'));
      if (await target.exists()) return;
      final data = await rootBundle.load('assets/sounds/chime.wav');
      await target.writeAsBytes(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('Falha ao instalar chime no iOS: $e');
    }
  }

  Future<void> playDrip() async {
    try {
      await _fx.stop();
      await _fx.play(AssetSource('sounds/drip.wav'), volume: 0.6);
    } catch (e) {
      debugPrint('drip: $e');
    }
    HapticFeedback.lightImpact();
  }

  /// Prévia da gravação. [onComplete] avisa quando terminar.
  Future<void> playPreview(String path, {VoidCallback? onComplete}) async {
    await _preview.stop();
    await _preview.setAudioContext(_mediaContext);
    StreamSubscription? sub;
    sub = _preview.onPlayerComplete.listen((_) {
      onComplete?.call();
      sub?.cancel();
    });
    await _preview.play(DeviceFileSource(path));
  }

  Future<void> stopPreview() => _preview.stop();

  /// Inicia o alarme em loop: voz gravada ou, sem gravação, o chime
  /// (mesma melodia Dó-Mi-Sol-Dó do PWA). Vibra em ciclos.
  Future<void> startAlarm({String? voicePath}) async {
    try {
      if (voicePath != null && await File(voicePath).exists()) {
        await _alarm.play(DeviceFileSource(voicePath));
      } else {
        await _alarm.play(AssetSource('sounds/chime.wav'));
      }
    } catch (e) {
      debugPrint('Falha ao tocar voz, usando chime: $e');
      await _alarm.play(AssetSource('sounds/chime.wav'));
    }
    _vibrationTimer?.cancel();
    HapticFeedback.heavyImpact();
    _vibrationTimer =
        Timer.periodic(const Duration(milliseconds: 750), (_) => HapticFeedback.heavyImpact());
  }

  Future<void> stopAlarm() async {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    await _alarm.stop();
  }
}
