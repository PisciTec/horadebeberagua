import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/stats.dart';

/// Gráfico de barras Seg→Dom (#weekly-chart do PWA).
class WeeklyChart extends StatelessWidget {
  final List<int> totals; // 7 valores, segunda primeiro
  final int goal;
  const WeeklyChart({super.key, required this.totals, required this.goal});

  static const _labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final todayIndex = DateTime.now().weekday - 1;
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final pct = percentOf(totals[i], goal) / 100;
          final isToday = i == todayIndex;
          final reached = totals[i] >= goal;
          return Expanded(
            child: Tooltip(
              message: '${totals[i]} ml',
              child: Column(children: [
                Expanded(
                  child: Container(
                    width: 22,
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: pct),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => FractionallySizedBox(
                        heightFactor: v,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: reached
                                  ? const [AppColors.success, Color(0xFF34D399)]
                                  : const [AppColors.primary, AppColors.accent],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}
