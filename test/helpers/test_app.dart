import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/app_dependencies.dart';
import 'package:wara2a/core/database/objectbox_database.dart';
import 'package:wara2a/features/invoice_capture/repositories/invoice_image_repository.dart';
import 'package:wara2a/features/settings/models/app_settings.dart';
import 'package:wara2a/features/settings/repositories/settings_repository.dart';
import 'package:wara2a/main.dart';

class MemorySettingsRepository implements SettingsRepository {
  AppSettings value = const AppSettings();

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}

Future<Directory> pumpTestApp(
  WidgetTester tester, {
  InvoiceImageRepository? imageRepository,
}) async {
  final directory = await Directory.systemTemp.createTemp('wara2a_widget_');
  final database = await ObjectBoxDatabase.open(directory: directory.path);
  final dependencies = AppDependencies.fromDatabase(
    database,
    settings: MemorySettingsRepository(),
  );
  await tester.pumpWidget(
    Wara2aApp(dependencies: dependencies, imageRepository: imageRepository),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    if (await directory.exists()) await directory.delete(recursive: true);
  });
  return directory;
}
