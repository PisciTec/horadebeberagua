import 'package:aquavoice/widgets/wave_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('WaveProgress mostra percentual e fração', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: WaveProgress(percent: 45, total: 900, goal: 2000))),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('900 / 2000 ml'), findsOneWidget);
  });
}
