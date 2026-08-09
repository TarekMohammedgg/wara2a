import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/invoice_capture/models/invoice_image_draft.dart';

class AppImageStorage {
  AppImageStorage({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  static String newDraftId() {
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch}_$random';
  }

  Future<void> recordPendingSource(InvoiceImageSource source) async {
    final marker = await _pendingMarker();
    await marker.parent.create(recursive: true);
    await marker.writeAsString(
      jsonEncode({'source': source.name}),
      flush: true,
    );
  }

  Future<InvoiceImageSource?> takePendingSource() async {
    final marker = await _pendingMarker();
    if (!await marker.exists()) return null;
    try {
      final values =
          jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
      final name = values['source'] as String?;
      return InvoiceImageSource.values
          .where((value) => value.name == name)
          .firstOrNull;
    } finally {
      await _deleteIfExists(marker);
    }
  }

  Future<void> clearPendingSource() async {
    await _deleteIfExists(await _pendingMarker());
  }

  Future<String> copyToDraft(XFile source, String extension) async {
    final directory = await _draftDirectory();
    await directory.create(recursive: true);
    final id = newDraftId();
    final destination = File(
      '${directory.path}${Platform.pathSeparator}$id.$extension',
    );
    final temporary = File('${destination.path}.part');
    try {
      await File(source.path).copy(temporary.path);
      await temporary.rename(destination.path);
      return destination.path;
    } catch (_) {
      await _deleteIfExists(temporary);
      await _deleteIfExists(destination);
      rethrow;
    }
  }

  Future<void> deleteDraft(String path) async {
    final directory = await _draftDirectory();
    final root = directory.absolute.path;
    final candidate = File(path).absolute.path;
    final prefix = '$root${Platform.pathSeparator}';
    if (!candidate.startsWith(prefix)) return;
    await _deleteIfExists(File(candidate));
  }

  Future<Directory> _draftDirectory() async {
    final documents = await _documentsDirectory();
    return Directory(
      '${documents.path}${Platform.pathSeparator}invoice_images${Platform.pathSeparator}drafts',
    );
  }

  Future<File> _pendingMarker() async {
    final documents = await _documentsDirectory();
    return File(
      '${documents.path}${Platform.pathSeparator}invoice_images${Platform.pathSeparator}.pending_capture.json',
    );
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
