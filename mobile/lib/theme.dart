import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta portada do index.css do PWA.
class AppColors {
  static const bgPrimary = Color(0xFF0B0F19);
  static const bgSecondary = Color(0xFF161E2E);
  static const glassBg = Color(0xB3161E2E);
  static const glassBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFF0EA5E9);
  static const accent = Color(0xFF38BDF8);
  static const success = Color(0xFF10B981);
  static const purple = Color(0xFF8B5CF6);
  static const danger = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const textMain = Color(0xFFF8FAFC);
  static const textMuted = Color(0xFF94A3B8);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.bgSecondary,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSurface: AppColors.textMain,
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textMain,
      displayColor: AppColors.textMain,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgPrimary.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.bgSecondary,
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.bgSecondary),
  );
}

/// Fundo com os dois gradientes radiais do PWA (azul no topo, roxo embaixo).
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgPrimary,
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.1,
                colors: [AppColors.primary.withValues(alpha: 0.15), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomRight,
                radius: 1.1,
                colors: [AppColors.purple.withValues(alpha: 0.15), Colors.transparent],
              ),
            ),
          ),
        ),
        child,
      ]),
    );
  }
}
