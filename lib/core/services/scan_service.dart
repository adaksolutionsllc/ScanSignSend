import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final scanServiceProvider = Provider<ScanService>((ref) => ScanService());

/// Wraps both the iOS (VisionKit) and Android (ML Kit) platform channels.
/// Returns a list of local image file paths — one per scanned page.
/// Returns an empty list if the user cancels.
class ScanService {
  static const _channel = MethodChannel('com.scansignsend/scanner');

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('scanAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Launches the native document camera. Returns image paths.
  Future<List<String>> scan() async {
    try {
      final result = await _channel.invokeListMethod<String>('scan');
      return result ?? [];
    } on PlatformException catch (e) {
      if (e.code == 'UNAVAILABLE') return [];
      rethrow;
    }
  }
}
