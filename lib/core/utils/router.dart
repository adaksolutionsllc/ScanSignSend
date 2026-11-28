import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/presentation/library_screen.dart';
import '../../features/capture/presentation/capture_screen.dart';
import '../../features/review/presentation/crop_screen.dart';
import '../../features/receipts/presentation/receipts_screen.dart';
import '../../features/review/presentation/job_screen.dart';
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
import '../services/import_job.dart';
import '../services/import_job_runner.dart';
import '../services/opened_file_service.dart';
import '../../features/settings/presentation/signatures_manager_screen.dart';
import '../../features/settings/presentation/my_details_screen.dart';

// Route path constants
class AppRoutes {
  static const library = '/';
  static const capture = '/capture';
  static const review = '/review/:docId';
  static const crop = '/crop/:docId';
  static const job = '/job/:docId';
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
  static const receipts = '/receipts';
}

/// Where a document with a long import job opens (plan 1.3.2): its job's
/// progress, or the crop screen when pages wait for the user. Null without
/// a job.
String? jobRouteFor(ImportJobRunner runner, int docId) {
  final view = runner.view(docId);
  if (view == null) return null;
  return (view.step == JobStep.choose ? AppRoutes.crop : AppRoutes.job)
      .replaceAll(':docId', '$docId');
}

final routerProvider = Provider<GoRouter>((ref) {
  // A document whose pages are still changing opens its job instead.
  String? toJob(GoRouterState state) => jobRouteFor(
    ref.read(importJobRunnerProvider),
    int.parse(state.pathParameters['docId']!),
  );
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
        redirect: (context, state) => toJob(state),
        builder: (context, state) => ReviewScreen(
          docId: int.parse(state.pathParameters['docId']!),
          organise: state.uri.queryParameters['organise'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.crop,
        builder: (context, state) => CropScreen(
          docId: int.parse(state.pathParameters['docId']!),
          // Add pages and Crop in Review hand over the pages in memory;
          // without them the pages come from the document's import job.
          candidates: state.extra as List<EdgeCandidate>?,
          // Opened from Review or Add pages: go back there when done.
          popWhenDone: state.uri.queryParameters['back'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.job,
        builder: (context, state) => JobScreen(
          docId: int.parse(state.pathParameters['docId']!),
          popWhenDone: state.uri.queryParameters['back'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.fieldDetection,
        builder: (context, state) => FieldDetectionScreen(
          docId: int.parse(state.pathParameters['docId']!),
          newPagesFrom: int.tryParse(state.uri.queryParameters['from'] ?? ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.fillMode,
        redirect: (context, state) => toJob(state),
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
        path: AppRoutes.receipts,
        builder: (context, state) => ReceiptsScreen(
          docIds: [
            for (final id in (state.uri.queryParameters['ids'] ?? '').split(
              ',',
            ))
              ?int.tryParse(id),
          ],
        ),
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
