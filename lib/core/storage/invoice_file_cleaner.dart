import 'dart:io';

abstract interface class InvoiceFileCleaner {
  Future<void> deleteOwnedFiles(Iterable<String?> paths);
}

class LocalInvoiceFileCleaner implements InvoiceFileCleaner {
  const LocalInvoiceFileCleaner({required this.managedRoot});

  final String managedRoot;

  @override
  Future<void> deleteOwnedFiles(Iterable<String?> paths) async {
    final root = _normalizedPath(Directory(managedRoot).absolute.path);
    final rootPrefix = root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';

    for (final path in paths.whereType<String>()) {
      final file = File(path);
      final absolutePath = _normalizedPath(file.absolute.path);
      if (!absolutePath.startsWith(rootPrefix)) continue;
      if (await file.exists()) await file.delete();
    }
  }

  String _normalizedPath(String path) {
    final normalized = Platform.isWindows
        ? path.replaceAll('/', Platform.pathSeparator)
        : path;
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }
}

class NoOpInvoiceFileCleaner implements InvoiceFileCleaner {
  const NoOpInvoiceFileCleaner();

  @override
  Future<void> deleteOwnedFiles(Iterable<String?> paths) async {}
}
