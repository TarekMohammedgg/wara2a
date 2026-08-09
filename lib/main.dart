import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/app_dependencies.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_bloc_observer.dart';
import 'features/invoice_capture/repositories/image_picker_invoice_image_repository.dart';
import 'features/invoice_capture/repositories/invoice_image_repository.dart';
import 'features/invoice_capture/view_models/invoice_capture_cubit.dart';
import 'features/settings/view_models/settings_cubit.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const AppBlocObserver();
  final dependencies = await AppDependencies.production();
  runApp(Wara2aApp(dependencies: dependencies));
}

class Wara2aApp extends StatefulWidget {
  const Wara2aApp({
    required this.dependencies,
    super.key,
    this.imageRepository,
  });

  final AppDependencies dependencies;
  final InvoiceImageRepository? imageRepository;

  @override
  State<Wara2aApp> createState() => _Wara2aAppState();
}

class _Wara2aAppState extends State<Wara2aApp> {
  late final GoRouter _router;
  late final InvoiceCaptureCubit _captureCubit;
  late final SettingsCubit _settingsCubit;

  @override
  void initState() {
    super.initState();
    _captureCubit = InvoiceCaptureCubit(
      widget.imageRepository ?? ImagePickerInvoiceImageRepository(),
    );
    _captureCubit.recoverLostData();
    _settingsCubit = SettingsCubit(widget.dependencies.settings)..load();
    _router = buildAppRouter(widget.dependencies);
  }

  @override
  void dispose() {
    _captureCubit.close();
    _settingsCubit.close();
    _router.dispose();
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _captureCubit),
        BlocProvider.value(value: _settingsCubit),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return MaterialApp.router(
            title: 'Wara2a',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: state.settings.themeMode,
            locale: Locale(state.settings.localeCode),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
