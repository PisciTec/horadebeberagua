import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/wave_progress.dart';

/// Aba "Consumo" (#tab-home do PWA).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _quick = [
    (ml: 200, label: 'Copo', icon: Icons.local_drink_outlined),
    (ml: 350, label: 'Copo Grande', icon: Icons.local_cafe_outlined),
    (ml: 500, label: 'Garrafa', icon: Icons.water_drop_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const SizedBox(height: 12),
        Center(
          child: WaveProgress(
            percent: state.todayPercent,
            total: state.todayTotal,
            goal: state.settings.dailyGoal,
          ),
        ),
        if (state.nextAlarm != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Próximo lembrete às ${_hm(state.nextAlarm!)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 28),
        const SectionTitle('Registro Rápido'),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final q in _quick) ...[
              Expanded(
                child: _QuickCard(
                  ml: q.ml,
                  label: q.label,
                  icon: q.icon,
                  onTap: () => state.addWater(q.ml, q.label),
                ),
              ),
              if (q != _quick.last) const SizedBox(width: 12),
            ],
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => _showCustomDialog(context, state),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Adicionar Quantidade Personalizada'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            minimumSize: const Size.fromHeight(54),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), style: BorderStyle.solid),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ],
    );
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _showCustomDialog(BuildContext context, AppState state) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) {
        void submit() {
          final v = int.tryParse(controller.text);
          if (v != null && v > 0 && v <= 5000) Navigator.pop(ctx, v);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: const Icon(Icons.water_drop, color: AppColors.primary, size: 40),
          title: const Text('Adicionar Água'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Digite a quantidade de água consumida:',
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(hintText: '300', suffixText: 'ml'),
              onSubmitted: (_) => submit(),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: submit, child: const Text('Registrar')),
          ],
        );
      },
    );
    if (amount != null) await state.addWater(amount, 'Personalizado');
  }
}

class _QuickCard extends StatefulWidget {
  final int ml;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickCard({required this.ml, required this.label, required this.icon, required this.onTap});

  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: Semantics(
          button: true,
          label: 'Registrar ${widget.ml} ml, ${widget.label}',
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(children: [
              Icon(widget.icon, color: AppColors.accent, size: 30),
              const SizedBox(height: 10),
              Text('${widget.ml} ml',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 2),
              Text(widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
