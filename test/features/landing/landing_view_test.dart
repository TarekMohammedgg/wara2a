import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wara2a/features/landing/views/landing_view.dart';

void main() {
  testWidgets('presents Wara2a welcome content and starts the dashboard', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('dashboard'))),
        ),
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const LandingView(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('كل فواتيرك في مكان واحد'), findsOneWidget);
    expect(find.text('ابدأ الآن'), findsOneWidget);

    final startButton = find.widgetWithText(FilledButton, 'ابدأ الآن');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('dashboard'), findsOneWidget);
  });
}
