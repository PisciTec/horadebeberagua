import 'dart:async';

import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../services/voice_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Gravação da voz do alarme com visualizador de onda (.recorder-container do PWA).
class VoiceRecorder extends StatefulWidget {
  const VoiceRecorder({super.key});

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> with SingleTickerProviderStateMixin {
  final _voice = VoiceService();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  StreamSubscription<double>? _levelSub;

  bool _recording = false;
  bool _playing = false;
  String? _status;
  final List<double> _levels = List.filled(40, 0);

  @override
  void dispose() {
    _levelSub?.cancel();
    _pulse.dispose();
    _voice.dispose();
    SoundService.instance.stopPreview();
    super.dispose();
  }

  Future<void> _toggle() async => _recording ? _stop() : _start();

  Future<void> _start() async {
    final ok = await _voice.start(onAutoStop: _stop);
    if (!ok) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permissão do Microfone'),
          content: const Text(
              'Para gravar seu alarme de voz personalizado, precisamos acessar o microfone. '
              'Conceda a permissão nos Ajustes do aparelho.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
        ),
      );
      return;
    }
    _levelSub = _voice.levels.listen((l) {
      if (!mounted) return;
      setState(() {
        _levels.removeAt(0);
        _levels.add(l);
      });
    });
    _pulse.repeat();
    setState(() {
      _recording = true;
      _status = 'Gravando... toque no microfone para parar (máx. 30 s)';
    });
  }

  Future<void> _stop() async {
    if (!_recording) return;
    await _levelSub?.cancel();
    _pulse.stop();
    final result = await _voice.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _levels.fillRange(0, _levels.length, 0);
      _status = result == null ? 'Falha ao salvar a gravação' : 'Gravação salva com sucesso!';
    });
    if (result != null) {
      await AppScope.read(context).setVoice(path: result.path, iosSoundName: result.iosSoundName);
    }
  }

  Future<void> _play(String path) async {
    if (_playing) {
      await SoundService.instance.stopPreview();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    await SoundService.instance.playPreview(path, onComplete: () {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _delete(AppState state) async {
    await SoundService.instance.stopPreview();
    await _voice.delete(state.voicePath);
    await state.setVoice(path: null);
    setState(() {
      _playing = false;
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(children: [
      SizedBox(
        width: 120,
        height: 120,
        child: Stack(alignment: Alignment.center, children: [
          if (_recording)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Container(
                width: 84 + 36 * _pulse.value,
                height: 84 + 36 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger.withValues(alpha: 0.35 * (1 - _pulse.value)),
                ),
              ),
            ),
          Semantics(
            button: true,
            label: _recording ? 'Parar gravação' : 'Gravar voz do alarme',
            child: GestureDetector(
              onTap: _toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _recording
                        ? const [AppColors.danger, Color(0xFFF87171)]
                        : const [AppColors.primary, AppColors.purple],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_recording ? AppColors.danger : AppColors.primary).withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(_recording ? Icons.stop_rounded : Icons.mic, color: Colors.white, size: 38),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Text(
        _status ?? (state.hasVoice ? 'Toque no microfone para gravar novamente' : 'Toque no microfone para gravar'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: _recording
            ? Padding(
                padding: const EdgeInsets.only(top: 14),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final l in _levels)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            height: 4 + 44 * l,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
      if (state.hasVoice && !_recording) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bgPrimary.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(children: [
            IconButton(
              onPressed: () => _play(state.voicePath!),
              icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              color: AppColors.accent,
              tooltip: _playing ? 'Pausar' : 'Ouvir gravação',
            ),
            const Expanded(child: Text('Gravação Salva', style: TextStyle(fontWeight: FontWeight.w500))),
            IconButton(
              onPressed: () => _delete(state),
              icon: const Icon(Icons.delete_outline),
              color: AppColors.danger,
              tooltip: 'Apagar gravação',
            ),
          ]),
        ),
      ],
    ]);
  }
}
