import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Tela cheia do alarme (#alarm-overlay do PWA). Toca a voz gravada em loop
/// (ou o chime) e vibra até o usuário responder.
class AlarmRingScreen extends StatefulWidget {
  final DateTime alarmTime;
  const AlarmRingScreen({super.key, required this.alarmTime});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SoundService.instance.startAlarm(voicePath: AppScope.read(context).voicePath);
    });
  }

  @override
  void dispose() {
    _shake.dispose();
    SoundService.instance.stopAlarm();
    super.dispose();
  }

  Future<void> _finish({required bool drank}) async {
    if (_closing) return;
    _closing = true;
    final state = AppScope.read(context);
    await SoundService.instance.stopAlarm();
    await state.handleAlarm(widget.alarmTime, drank: drank);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0C4A6E), AppColors.bgPrimary],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                const Spacer(),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) => Transform.rotate(
                    angle: (_shake.value - 0.5) * 0.5,
                    child: child,
                  ),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.2),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 50)],
                    ),
                    child: const Icon(Icons.notifications_active, size: 72, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Hora de Beber Água!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Seu corpo precisa de hidratação. Beba um copo d\'água agora para manter sua saúde em dia!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textMuted, height: 1.4),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Bebi! Parar Lembrete (+250 ml)',
                  icon: Icons.water_drop,
                  onPressed: () => _finish(drank: true),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _finish(drank: false),
                  child: const Text('Dispensar sem registrar',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
