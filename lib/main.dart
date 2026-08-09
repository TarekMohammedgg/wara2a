import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/app_controller.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const Wara2aApp());
}

class Wara2aApp extends StatefulWidget {
  const Wara2aApp({super.key});

  @override
  State<Wara2aApp> createState() => _Wara2aAppState();
}

class _Wara2aAppState extends State<Wara2aApp> {
  late final GoRouter _router;
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _router = buildAppRouter();
  }

  @override
  void dispose() {
    _controller.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppControllerScope(
          controller: _controller,
          child: MaterialApp.router(
            title: 'Wara2a',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _controller.themeMode,
            locale: _controller.locale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
          ),
        );
      },
    );
  }
}
