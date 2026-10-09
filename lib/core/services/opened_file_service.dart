import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A PDF the user opened with this app from somewhere else.
class OpenedFile {
  const OpenedFile({required this.path, required this.name});

  /// The app's own temporary copy; deleted once imported.
  final String path;

  /// The original file name, used for the document title.
  final String name;
}

final openedFileServiceProvider = Provider<OpenedFileService>((ref) {
  final service = OpenedFileService();
  ref.onDispose(service.dispose);
  return service;
});

/// PDFs opened with Scan Sign Send from Files, Mail, Drive, a browser or a
/// share sheet ("Open in…" on iOS, the PDF intent filters on Android).
///
/// The native side copies each file into the app's temp storage and queues
/// it, because on a cold launch the file arrives before Dart is listening.
/// [start] collects whatever is already queued; after that native pings
/// `pending` for each new arrival. Native code: OpenFilePlugin.swift,
/// OpenFileHandler.kt.
class OpenedFileService {
  static const _channel = MethodChannel('com.scansignsend/open_file');

  final _controller = StreamController<OpenedFile>.broadcast();

  Stream<OpenedFile> get files => _controller.stream;

  /// Call once a listener is attached to [files].
  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pending') await _takePending();
    });
    await _takePending();
  }

  Future<void> _takePending() async {
    try {
      final list = await _channel.invokeListMethod<Map>('takePending') ?? [];
      for (final m in list) {
        final path = m['path'] as String?;
        if (path == null) continue;
        _controller.add(
          OpenedFile(path: path, name: (m['name'] as String?) ?? 'Document'),
        );
      }
    } on MissingPluginException {
      // Tests / unsupported platforms: nothing is ever opened.
    } catch (e) {
      debugPrint('OpenedFileService: $e');
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _controller.close();
  }
}
