import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A PDF or photo the user opened with this app from somewhere else.
class OpenedFile {
  const OpenedFile({required this.path, required this.name, this.batch});

  /// The app's own temporary copy; deleted once imported.
  final String path;

  /// The original file name, used for the document title.
  final String name;

  /// Files opened in one go (one share, one "Open in…") share a batch.
  final String? batch;
}

final openedFileServiceProvider = Provider<OpenedFileService>((ref) {
  final service = OpenedFileService();
  ref.onDispose(service.dispose);
  return service;
});

/// PDFs and photos opened with Scan Sign Send from Files, Mail, Drive, a
/// browser or a share sheet ("Open in…" on iOS, the intent filters on
/// Android).
///
/// Files that arrive together come out as groups: each PDF on its own, and
/// all the photos as one group, which becomes one document.
///
/// The native side copies each file into the app's temp storage and queues
/// it, because on a cold launch the file arrives before Dart is listening.
/// [start] collects whatever is already queued; after that native pings
/// `pending` for each new arrival. Native code: OpenFilePlugin.swift,
/// OpenFileHandler.kt.
class OpenedFileService {
  static const _channel = MethodChannel('com.scansignsend/open_file');

  final _controller = StreamController<List<OpenedFile>>.broadcast();

  Stream<List<OpenedFile>> get files => _controller.stream;

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
      final files = [
        for (final m in list)
          if (m['path'] is String)
            OpenedFile(
              path: m['path'] as String,
              name: (m['name'] as String?) ?? 'Document',
              batch: m['batch'] as String?,
            ),
      ];
      for (final group in groupOpened(files)) {
        _controller.add(group);
      }
    } on MissingPluginException {
      // Tests / unsupported platforms: nothing is ever opened.
    } catch (e) {
      debugPrint('OpenedFileService: $e');
    }
  }

  /// Each PDF alone; the photos of one batch together, in arrival order.
  /// Photos opened separately (say, two shares while the app was starting)
  /// stay separate documents.
  @visibleForTesting
  static List<List<OpenedFile>> groupOpened(List<OpenedFile> files) {
    bool isImage(OpenedFile f) => _imageExtension.hasMatch(f.name);
    final photos = <String?, List<OpenedFile>>{};
    for (final f in files.where(isImage)) {
      (photos[f.batch] ??= []).add(f);
    }
    return [
      for (final f in files)
        if (!isImage(f)) [f],
      ...photos.values,
    ];
  }

  static final _imageExtension = RegExp(
    r'\.(jpe?g|png|heic|heif)$',
    caseSensitive: false,
  );

  void dispose() {
    _channel.setMethodCallHandler(null);
    _controller.close();
  }
}
