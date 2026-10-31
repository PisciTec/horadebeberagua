import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/alarm_ring_screen.dart';
import 'screens/alarm_settings_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState();
  runApp(AquaVoiceApp(state: state));
  // Inicializa depois do primeiro frame para a tela abrir rápido.
  unawaited(state.init());
}

class AquaVoiceApp extends StatefulWidget {
  final AppState state;
  const AquaVoiceApp({super.key, required this.state});

  @override
  State<AquaVoiceApp> createState() => _AquaVoiceAppState();
}

class _AquaVoiceAppState extends State<AquaVoiceApp> with WidgetsBindingObserver {
  StreamSubscription<DateTime>? _ringSub;
  bool _ringing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ringSub = widget.state.ringRequests.listen(_showRing);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) widget.state.onResumed();
  }

  Future<void> _showRing(DateTime alarmTime) async {
    if (_ringing) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    _ringing = true;
    await nav.push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AlarmRingScreen(alarmTime: alarmTime),
    ));
    _ringing = false;
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: MaterialApp(
        title: 'AquaVoice',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: buildTheme(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const MainShell(),
      ),
    );
  }
}

/// Estrutura com cabeçalho + 3 abas + barra de navegação inferior.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static const _pages = [HomeScreen(), AlarmSettingsScreen(), HistoryScreen()];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                const Icon(Icons.water_drop, color: AppColors.primary, size: 28),
                const SizedBox(width: 8),
                const Text('AquaVoice', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_fire_department, color: AppColors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('${state.streak} dias seguidos',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
            Expanded(child: IndexedStack(index: _tab, children: _pages)),
          ]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: AppColors.bgSecondary,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 2) state.refresh(); // redesenha o gráfico, como no PWA
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Consumo'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Alarmes'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Histórico'),
        ],
      ),
    );
  }
}
