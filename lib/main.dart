import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/app_controller.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/invoice_capture/repositories/image_picker_invoice_image_repository.dart';
import 'features/invoice_capture/repositories/invoice_image_repository.dart';
import 'features/invoice_capture/view_models/invoice_capture_cubit.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const Wara2aApp());
}

class Wara2aApp extends StatefulWidget {
  const Wara2aApp({super.key, this.imageRepository});

  final InvoiceImageRepository? imageRepository;

  @override
  State<Wara2aApp> createState() => _Wara2aAppState();
}

class _Wara2aAppState extends State<Wara2aApp> {
  late final GoRouter _router;
  late final AppController _controller;
  late final InvoiceCaptureCubit _captureCubit;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _captureCubit = InvoiceCaptureCubit(
      widget.imageRepository ?? ImagePickerInvoiceImageRepository(),
    );
    _captureCubit.recoverLostData();
    _router = buildAppRouter();
  }

  @override
  void dispose() {
    _controller.dispose();
    _captureCubit.close();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _captureCubit,
      child: AnimatedBuilder(
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
      ),
    );
  }
}
