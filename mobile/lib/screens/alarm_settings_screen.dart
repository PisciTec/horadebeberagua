import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/settings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/voice_recorder.dart';

/// Aba "Alarmes" (#tab-alarm do PWA).
class AlarmSettingsScreen extends StatefulWidget {
  const AlarmSettingsScreen({super.key});

  @override
  State<AlarmSettingsScreen> createState() => _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends State<AlarmSettingsScreen> {
  late final TextEditingController _goal;
  late final TextEditingController _interval;
  final _goalFocus = FocusNode();
  final _intervalFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context).settings;
    _goal = TextEditingController(text: '${s.dailyGoal}');
    _interval = TextEditingController(text: '${s.alarmInterval}');
    _goalFocus.addListener(() {
      if (!_goalFocus.hasFocus) _commitGoal();
    });
    _intervalFocus.addListener(() {
      if (!_intervalFocus.hasFocus) _commitInterval();
    });
  }

  @override
  void dispose() {
    _goal.dispose();
    _interval.dispose();
    _goalFocus.dispose();
    _intervalFocus.dispose();
    super.dispose();
  }

  void _commitGoal() {
    final state = AppScope.read(context);
    final v = int.tryParse(_goal.text) ?? state.settings.dailyGoal;
    final next = state.settings.copyWith(dailyGoal: v);
    _goal.text = '${next.dailyGoal}';
    state.updateSettings(next);
  }

  void _commitInterval() {
    final state = AppScope.read(context);
    final v = int.tryParse(_interval.text) ?? state.settings.alarmInterval;
    final next = state.settings.copyWith(alarmInterval: v);
    _interval.text = '${next.alarmInterval}';
    state.updateSettings(next);
  }

  Future<void> _pickTime(AppState state, {required bool isStart}) async {
    final current = isStart ? state.settings.alarmStart : state.settings.alarmEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      builder: (ctx, child) =>
          MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    final t = ClockTime(picked.hour, picked.minute);
    await state.updateSettings(
        isStart ? state.settings.copyWith(alarmStart: t) : state.settings.copyWith(alarmEnd: t));
  }

  Future<void> _toggleAlarms(AppState state, bool value) async {
    final ok = await state.setAlarmsEnabled(value);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Permita as notificações nos Ajustes para receber os lembretes.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.settings;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Meta de Consumo'),
              const SizedBox(height: 16),
              _Label('Meta Diária (ml)'),
              TextField(
                controller: _goal,
                focusNode: _goalFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(suffixText: 'ml'),
                onSubmitted: (_) => _commitGoal(),
              ),
            ]),
          ),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text('Lembretes de Água',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                Switch(value: s.alarmsEnabled, onChanged: (v) => _toggleAlarms(state, v)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: _TimeField(
                    label: 'Início',
                    value: s.alarmStart.toString(),
                    onTap: () => _pickTime(state, isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: 'Fim',
                    value: s.alarmEnd.toString(),
                    onTap: () => _pickTime(state, isStart: false),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _Label('Intervalo (minutos)'),
              TextField(
                controller: _interval,
                focusNode: _intervalFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(suffixText: 'min', helperText: 'Entre 5 e 360 minutos'),
                onSubmitted: (_) => _commitInterval(),
              ),
              if (s.alarmsEnabled && state.nextAlarm != null) ...[
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text('Próximo lembrete: ${_fmt(state.nextAlarm!)}',
                      style: const TextStyle(color: AppColors.success, fontSize: 13)),
                ]),
              ],
              const SizedBox(height: 16),
              const TipBox(
                title: 'Recorrência',
                text: 'O alarme é ativado automaticamente todos os dias, dentro da janela de horários '
                    'configurada, mesmo com o app fechado.',
              ),
              if (Platform.isAndroid && s.alarmsEnabled) ...[
                const SizedBox(height: 12),
                TipBox(
                  title: 'Tela cheia',
                  color: AppColors.amber,
                  text: 'Para o alarme abrir por cima de tudo (inclusive com a tela bloqueada), '
                      'permita "Notificações em tela cheia" para o AquaVoice.',
                ),
                TextButton.icon(
                  onPressed: state.requestFullScreenPermission,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Abrir configuração'),
                ),
              ],
              if (Platform.isIOS && s.alarmsEnabled) ...[
                const SizedBox(height: 12),
                const TipBox(
                  title: 'No iPhone',
                  color: AppColors.amber,
                  text: 'Com o app fechado, o lembrete chega como notificação tocando a sua voz '
                      '(até 30 s). Toque nela para abrir a tela do alarme. Deixe o iPhone fora do '
                      'modo silencioso para ouvir o som.',
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: state.testRing,
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Testar alarme agora'),
                ),
              ),
            ]),
          ),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              SectionTitle('Som de Alarme com sua Voz'),
              SizedBox(height: 16),
              Center(child: VoiceRecorder()),
              SizedBox(height: 16),
              TipBox(
                title: 'Importante',
                text: 'Se você não gravar sua voz, o aplicativo usa um toque sintetizado. '
                    'A gravação tem no máximo 30 segundos.',
              ),
            ]),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime t) {
    final now = DateTime.now();
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final isToday = t.year == now.year && t.month == now.month && t.day == now.day;
    return isToday ? 'hoje às $hm' : 'amanhã às $hm';
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label(label),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: const InputDecoration(suffixIcon: Icon(Icons.access_time, size: 18)),
          child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      ),
    ]);
  }
}
