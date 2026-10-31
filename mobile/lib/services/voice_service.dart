import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Gravação da voz usada como alarme.
///
/// Grava em WAV PCM 16 bits mono: é o formato aceito pelo iOS como som de
/// notificação (AAC/m4a não é). No iOS o arquivo é copiado para
/// Library/Sounds, onde o sistema procura sons customizados.
class VoiceService {
  static const maxDuration = Duration(seconds: 29); // limite do iOS para som de notificação

  final _recorder = AudioRecorder();
  Timer? _autoStop;
  StreamSubscription<Amplitude>? _ampSub;

  /// Nível do microfone normalizado 0..1, para o visualizador de onda.
  final _levels = StreamController<double>.broadcast();
  Stream<double> get levels => _levels.stream;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> isRecording() => _recorder.isRecording();

  /// Inicia a gravação. [onAutoStop] é chamado se atingir o tempo máximo.
  Future<bool> start({required Future<void> Function() onAutoStop}) async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'voice_recording_tmp.wav');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: path,
    );

    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((a) => _levels.add(((a.current + 50) / 50).clamp(0.0, 1.0).toDouble()));

    _autoStop?.cancel();
    _autoStop = Timer(maxDuration, () => onAutoStop());
    return true;
  }

  /// Para a gravação e salva definitivamente.
  /// Retorna (caminho do arquivo, nome do som para iOS).
  Future<({String path, String? iosSoundName})?> stop() async {
    _autoStop?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    final tmp = await _recorder.stop();
    if (tmp == null) return null;

    final docs = await getApplicationDocumentsDirectory();
    final finalPath = p.join(docs.path, 'voice_alarm.wav');
    await File(tmp).rename(finalPath);

    String? soundName;
    if (Platform.isIOS) {
      // Nome versionado: o iOS faz cache do som pelo nome do arquivo.
      final soundsDir = await _iosSoundsDir();
      await _deleteOldVoiceSounds(soundsDir);
      soundName = 'voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await File(finalPath).copy(p.join(soundsDir.path, soundName));
    }
    return (path: finalPath, iosSoundName: soundName);
  }

  Future<void> delete(String? path) async {
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    if (Platform.isIOS) await _deleteOldVoiceSounds(await _iosSoundsDir());
  }

  static Future<Directory> _iosSoundsDir() async {
    final lib = await getLibraryDirectory();
    final dir = Directory(p.join(lib.path, 'Sounds'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<void> _deleteOldVoiceSounds(Directory dir) async {
    await for (final e in dir.list()) {
      if (e is File && p.basename(e.path).startsWith('voice_')) await e.delete();
    }
  }

  void dispose() {
    _autoStop?.cancel();
    _ampSub?.cancel();
    _levels.close();
    _recorder.dispose();
  }
}
