import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves file paths that were persisted with an absolute prefix.
///
/// On iOS the app's data container is at
/// `/var/mobile/Containers/Data/Application/<UUID>/Documents/...` and that
/// `<UUID>` changes on every reinstall (and can change on OS migration/restore).
/// We historically stored **absolute** paths in the DB, so after a reinstall the
/// stored prefix points at a container that no longer exists → "Image not found"
/// / blank PDF.
///
/// This helper rebases any stored path onto the *current* Documents directory by
/// keeping only the portion from the app-owned sub-folder onward (`pages/`,
/// `pressed/`, `fillable/`, `signatures/`). New code should store paths relative
/// to Documents; this also repairs the old absolute ones on read.
class PathResolver {
  PathResolver._();

  static Directory? _docsDir;

  /// Must be called once at startup (before any path resolution).
  static Future<void> init() async {
    _docsDir = await getApplicationDocumentsDirectory();
  }

  /// The app-owned top-level folders we persist files under.
  static const _ownedRoots = {'pages', 'pressed', 'fillable', 'signatures'};

  /// Returns an absolute, currently-valid path for [stored].
  ///
  /// Handles: a `#page=N` PDF fragment (preserved), already-relative paths, and
  /// stale absolute paths from a previous container.
  static String resolve(String stored) {
    final docs = _docsDir;
    if (docs == null) return stored; // not initialised — best effort

    // Preserve a "#page=N" fragment while rebasing the file part.
    String path = stored;
    String frag = '';
    final hash = stored.indexOf('#page=');
    if (hash >= 0) {
      path = stored.substring(0, hash);
      frag = stored.substring(hash);
    }

    final rel = _relativeUnderOwnedRoot(path);
    if (rel == null) return stored; // unknown shape — leave as-is
    return p.join(docs.path, rel) + frag;
  }

  /// Given any absolute-or-relative path, returns the portion starting at the
  /// first app-owned root folder (e.g. `pages/<uuid>/page_0.jpg`), or null if
  /// none is present.
  static String? _relativeUnderOwnedRoot(String path) {
    final parts = p.split(path);
    for (var i = 0; i < parts.length; i++) {
      if (_ownedRoots.contains(parts[i])) {
        return p.joinAll(parts.sublist(i));
      }
    }
    return null;
  }

  /// Converts an absolute path under Documents into a path we can safely store.
  /// (Kept relative-under-owned-root so it survives container changes.)
  static String toStorable(String absolute) =>
      _relativeUnderOwnedRoot(absolute) ?? absolute;
}
