import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/presentation/library_screen.dart';
import '../../features/capture/presentation/capture_screen.dart';
import '../../features/review/presentation/crop_screen.dart';
import '../../features/review/presentation/review_screen.dart';
import '../../features/field_detection/presentation/field_detection_screen.dart';
import '../../features/fill_mode/presentation/fill_mode_screen.dart';
import '../../features/signature/presentation/signature_capture_screen.dart';
import '../../features/press/presentation/press_screen.dart';
import '../../features/send/presentation/send_screen.dart';
import '../../features/library/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/viewer/presentation/document_viewer_screen.dart';
import '../services/edge_check_service.dart';
import '../services/opened_file_service.dart';
import '../../features/settings/presentation/signatures_manager_screen.dart';
import '../../features/settings/presentation/my_details_screen.dart';

// Route path constants
class AppRoutes {
  static const library = '/';
  static const capture = '/capture';
  static const review = '/review/:docId';
  static const crop = '/crop/:docId';
  static const fieldDetection = '/field-detection/:docId';
  static const fillMode = '/fill/:docId';
  static const signatureCapture = '/signature/:docId/:fieldId';
  static const press = '/press/:docId';
  static const send = '/send/:docId';
  static const settings = '/settings';
  static const search = '/search';
  static const signaturesManager = '/settings/signatures';
  static const myDetails = '/settings/my-details';
  static const viewer = '/viewer/:docId';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.library,
    routes: [
      GoRoute(
        path: AppRoutes.library,
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: AppRoutes.capture,
        builder: (context, state) => CaptureScreen(
          openedFiles: state.extra as List<OpenedFile>?,
          action: switch (state.uri.queryParameters['action']) {
            'scan' => CaptureAction.scan,
            'import' => CaptureAction.import,
            _ => null,
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.review,
        builder: (context, state) =>
            ReviewScreen(docId: int.parse(state.pathParameters['docId']!)),
      ),
      GoRoute(
        path: AppRoutes.crop,
        builder: (context, state) {
          final docId = int.parse(state.pathParameters['docId']!);
          final candidates = state.extra as List<EdgeCandidate>?;
          // The pages to check only travel in memory; without them (a
          // restored route) there is nothing to ask, so show Review.
          return candidates == null || candidates.isEmpty
              ? ReviewScreen(docId: docId)
              : CropScreen(docId: docId, candidates: candidates);
        },
      ),
      GoRoute(
        path: AppRoutes.fieldDetection,
        builder: (context, state) => FieldDetectionScreen(
          docId: int.parse(state.pathParameters['docId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.fillMode,
        builder: (context, state) =>
            FillModeScreen(docId: int.parse(state.pathParameters['docId']!)),
      ),
      GoRoute(
        path: AppRoutes.signatureCapture,
        builder: (context, state) => SignatureCaptureScreen(
          docId: int.parse(state.pathParameters['docId']!),
          fieldId: int.parse(state.pathParameters['fieldId']!),
          initials: state.uri.queryParameters['initials'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.press,
        builder: (context, state) =>
            PressScreen(docId: int.parse(state.pathParameters['docId']!)),
      ),
      GoRoute(
        path: AppRoutes.send,
        builder: (context, state) =>
            SendScreen(docId: int.parse(state.pathParameters['docId']!)),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.signaturesManager,
        builder: (context, state) => const SignaturesManagerScreen(),
      ),
      GoRoute(
        path: AppRoutes.myDetails,
        builder: (context, state) => const MyDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.viewer,
        builder: (context, state) => DocumentViewerScreen(
          docId: int.parse(state.pathParameters['docId']!),
        ),
      ),
    ],
  );
});
