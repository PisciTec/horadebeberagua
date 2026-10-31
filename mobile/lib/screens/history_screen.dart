import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/weekly_chart.dart';

/// Aba "Histórico" (#tab-history do PWA).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final weekTotal = state.weekTotals.fold<int>(0, (a, b) => a + b);
    final daysWithData = state.weekTotals.where((t) => t > 0).length;
    final avg = daysWithData == 0 ? 0 : (weekTotal / daysWithData).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Estatísticas da Semana'),
            const SizedBox(height: 6),
            Text('Média de $avg ml por dia registrado',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 18),
            WeeklyChart(totals: state.weekTotals, goal: state.settings.dailyGoal),
          ]),
        ),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: SectionTitle('Consumo de Hoje')),
              IconButton(
                tooltip: 'Limpar Histórico',
                color: AppColors.danger,
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _confirmClear(context, state),
              ),
            ]),
            const SizedBox(height: 8),
            if (state.todayLogs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text('Nenhum copo de água registrado hoje.',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              for (final r in state.todayLogs)
                Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppColors.danger),
                  ),
                  onDismissed: (_) => state.removeRecord(r.id!),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.water_drop_outlined, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${r.amount} ml',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          Text('${r.type} às ${_hm(r.timestamp)}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ]),
                      ),
                      IconButton(
                        tooltip: 'Remover',
                        icon: const Icon(Icons.close, size: 18),
                        color: AppColors.textMuted,
                        onPressed: () => state.removeRecord(r.id!),
                      ),
                    ]),
                  ),
                ),
          ]),
        ),
      ],
    );
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _confirmClear(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar histórico'),
        content: const Text('Tem certeza que deseja limpar todo o histórico de consumo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (ok == true) await state.clearHistory();
  }
}
