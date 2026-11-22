// Crop any page from Review (F5): the corner editor opens on one page, the
// page image is cut to the corners, and the page's fields move with the
// content (or go, when the crop cuts them away).

import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/document_edges.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/edge_check_service.dart';
import 'package:scan_sign_send/core/services/page_raster_service.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/features/review/presentation/crop_screen.dart';
import 'package:scan_sign_send/features/review/presentation/review_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A skewed document, as a photo of paper on a table gives.
const _skewed = EdgeQuad(
  math.Point(0.12, 0.08),
  math.Point(0.86, 0.14),
  math.Point(0.9, 0.93),
  math.Point(0.07, 0.88),
);

/// The image point that lands on (u, v) of the cropped image — the map
/// cropToQuad samples with.
math.Point<double> _forward(EdgeQuad q, double u, double v) => math.Point(
  q.tl.x * (1 - u) * (1 - v) +
      q.tr.x * u * (1 - v) +
      q.br.x * u * v +
      q.bl.x * (1 - u) * v,
  q.tl.y * (1 - u) * (1 - v) +
      q.tr.y * u * (1 - v) +
      q.br.y * u * v +
      q.bl.y * (1 - u) * v,
);

void main() {
  group('moving fields with the crop', () {
    test('toCropped undoes the crop map', () {
      for (final (u, v) in [
        (0.0, 0.0),
        (1.0, 1.0),
        (0.3, 0.7),
        (0.9, 0.1),
        (0.5, 0.5),
        (-0.2, 0.4), // cut away
      ]) {
        final back = _skewed.toCropped(_forward(_skewed, u, v));
        expect(back.x, closeTo(u, 1e-6), reason: '($u, $v)');
        expect(back.y, closeTo(v, 1e-6), reason: '($u, $v)');
      }
      // A plain inset crop is a scale and a shift.
      const inset = EdgeQuad(
        math.Point(0.1, 0.2),
        math.Point(0.9, 0.2),
        math.Point(0.9, 0.7),
        math.Point(0.1, 0.7),
      );
      final c = inset.toCropped(const math.Point(0.5, 0.45));
      expect(c.x, closeTo(0.5, 1e-9));
      expect(c.y, closeTo(0.5, 1e-9));
    });

    test('a box is moved, cut to the page, or dropped', () {
      const inset = EdgeQuad(
        math.Point(0.1, 0.2),
        math.Point(0.9, 0.2),
        math.Point(0.9, 0.7),
        math.Point(0.1, 0.7),
      );
      final moved = croppedBox(
        const BoundingBox(x: 0.3, y: 0.3, w: 0.4, h: 0.1),
        inset,
      )!;
      expect(moved.x, closeTo(0.25, 1e-9));
      expect(moved.y, closeTo(0.2, 1e-9));
      expect(moved.w, closeTo(0.5, 1e-9));
      expect(moved.h, closeTo(0.2, 1e-9));

      // Half over the cut edge: the half left on the page stays.
      final cut = croppedBox(
        const BoundingBox(x: 0.5, y: 0.6, w: 0.2, h: 0.2),
        inset,
      )!;
      expect(cut.y + cut.h, closeTo(1.0, 1e-9));
      expect(cut.h, closeTo(0.2, 1e-9));

      // Wholly in the cut-away margin.
      expect(
        croppedBox(const BoundingBox(x: 0.3, y: 0.8, w: 0.3, h: 0.1), inset),
        isNull,
      );
    });

    test('corners left on the image corners mean no crop', () {
      expect(EdgeQuad.full.isWhole, isTrue);
      expect(_skewed.isWhole, isFalse);
    });
  });

  group('Crop in Review', () {
    final l10n = AppLocalizationsEn();
    late AppDatabase db;
    late Directory root;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      root = Directory.systemTemp.createTempSync('sss_crop_');
      PathResolver.debugSetDocsDir(root);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        )
        ..setMockMethodCallHandler(
          const MethodChannel('google_mlkit_text_recognizer'),
          (_) async => null,
        );
      db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });
    tearDown(() async {
      await db.close();
      root.deleteSync(recursive: true);
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    testWidgets('Crop opens on the page, cuts it, and moves its fields', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      // Page 1 is a plain image; page 2 a sheet of paper on a dark table.
      final (docId, page2, original) = (await tester.runAsync(() async {
        final docs = DocumentRepository(db);
        final pages = PageRepository(db);
        final fields = FieldRepository(db);
        final doc = await docs.createDocument('Lease');
        final dir = Directory(p.join(root.path, 'pages', 'scan'))
          ..createSync(recursive: true);
        final plain = File(p.join(dir.path, 'page_0.jpg'))
          ..writeAsBytesSync(img.encodeJpg(img.Image(width: 300, height: 400)));
        final photo = img.Image(width: 600, height: 800);
        img.fill(photo, color: img.ColorRgb8(60, 50, 45));
        img.fillRect(
          photo,
          x1: 120,
          y1: 160,
          x2: 480,
          y2: 640,
          color: img.ColorRgb8(245, 245, 240),
        );
        final sheet = File(p.join(dir.path, 'page_1.jpg'))
          ..writeAsBytesSync(img.encodeJpg(photo));
        await pages.addPage(
          documentId: doc.id,
          pageIndex: 0,
          imagePath: plain.path,
        );
        final id2 = await pages.addPage(
          documentId: doc.id,
          pageIndex: 1,
          imagePath: sheet.path,
        );
        for (final (page, box) in [
          (0, const BoundingBox(x: 0.1, y: 0.05, w: 0.3, h: 0.05)),
          (1, const BoundingBox(x: 0.3, y: 0.4, w: 0.4, h: 0.05)), // on paper
          (1, const BoundingBox(x: 0.02, y: 0.02, w: 0.1, h: 0.05)), // table
        ]) {
          await fields.addField(
            FieldsCompanion.insert(
              documentId: doc.id,
              pageIndex: page,
              type: 'text',
              boundingBoxJson: box.toJsonString(),
              label: const Value('Name'),
            ),
          );
        }
        return (doc.id, id2, sheet.path);
      }))!;

      final router = GoRouter(
        initialLocation: AppRoutes.review.replaceAll(':docId', '$docId'),
        routes: [
          GoRoute(
            path: AppRoutes.review,
            builder: (_, _) => ReviewScreen(docId: docId),
          ),
          GoRoute(
            path: AppRoutes.crop,
            builder: (_, state) => CropScreen(
              docId: docId,
              candidates: state.extra! as List<EdgeCandidate>,
              popWhenDone: state.uri.queryParameters['back'] == '1',
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: kLocalizationsDelegates,
            supportedLocales: kSupportedLocales,
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.byKey(ValueKey('crop-page-$page2')));
      await settle(tester);
      expect(find.byType(CropScreen), findsOneWidget);
      // It starts on the whole image: no second guess at the edges.
      final screen = tester.widget<CropScreen>(find.byType(CropScreen));
      expect(screen.candidates.single.pageId, page2);
      expect(screen.candidates.single.quad.isWhole, isTrue);

      // Drag the top-left corner in over the table, then crop.
      final shown = tester.getRect(
        find.descendant(
          of: find.byType(CropScreen),
          matching: find.byType(Image),
        ),
      );
      final drag = await tester.startGesture(shown.topLeft);
      for (var i = 0; i < 10; i++) {
        await drag.moveBy(Offset(shown.width / 50, shown.height / 50));
        await tester.pump();
      }
      await drag.up();
      await tester.pump();
      await tester.tap(find.text(l10n.cropApply));
      await settle(tester);
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(find.byType(CropScreen), findsNothing);

      final (pages, fields) = (await tester.runAsync(
        () async => (
          await PageRepository(db).pagesOf(docId),
          await FieldRepository(db).watchFields(docId).first,
        ),
      ))!;
      final cropped = PathResolver.resolve(pages[1].imagePath);
      expect(cropped, isNot(original));
      expect(File(original).existsSync(), isFalse, reason: 'old image kept');

      // Page 1's field is untouched; on page 2 the field on the paper
      // stays and the one on the table went with the table.
      expect(fields, hasLength(2));
      final first = BoundingBox.fromJsonString(
        fields.firstWhere((f) => f.pageIndex == 0).boundingBoxJson,
      );
      expect(first.x, 0.1);
      expect(fields.where((f) => f.pageIndex == 1), hasLength(1));
    });

    test('a crop moves the page\'s fields with the content', () async {
      final docs = DocumentRepository(db);
      final pages = PageRepository(db);
      final fields = FieldRepository(db);
      final doc = await docs.createDocument('Lease');
      final dir = Directory(p.join(root.path, 'pages', 'lease'))
        ..createSync(recursive: true);
      final file = File(p.join(dir.path, 'page_0.jpg'))
        ..writeAsBytesSync(img.encodeJpg(img.Image(width: 600, height: 800)));
      final pageId = await pages.addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: file.path,
      );
      final fieldId = await fields.addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: 0,
          type: 'text',
          boundingBoxJson: const BoundingBox(
            x: 0.3,
            y: 0.4,
            w: 0.4,
            h: 0.05,
          ).toJsonString(),
        ),
      );
      const sheet = EdgeQuad(
        math.Point(0.2, 0.2),
        math.Point(0.8, 0.2),
        math.Point(0.8, 0.8),
        math.Point(0.2, 0.8),
      );
      final service = EdgeCheckService(docs, pages, PageRasterService());
      expect(await service.apply(doc.id, {pageId: sheet}), isEmpty);
      // Nothing to cut: the image is not rewritten.
      final path = (await pages.pagesOf(doc.id)).single.imagePath;
      expect(await service.apply(doc.id, {pageId: EdgeQuad.full}), isEmpty);
      expect((await pages.pagesOf(doc.id)).single.imagePath, path);

      final moved = BoundingBox.fromJsonString(
        (await fields.watchFields(doc.id).first)
            .singleWhere((f) => f.id == fieldId)
            .boundingBoxJson,
      );
      // x 0.3 of the photo is (0.3 - 0.2) / 0.6 of the sheet.
      expect(moved.x, closeTo(1 / 6, 1e-6));
      expect(moved.y, closeTo(1 / 3, 1e-6));
      expect(moved.w, closeTo(2 / 3, 1e-6));
      expect(moved.h, closeTo(0.05 / 0.6, 1e-6));
    });

    testWidgets('PDF pages have no Crop: their content is not an image', (
      tester,
    ) async {
      final (docId, pageId) = (await tester.runAsync(() async {
        final doc = await DocumentRepository(db).createDocument('Form');
        final id = await PageRepository(db).addPage(
          documentId: doc.id,
          pageIndex: 0,
          imagePath: p.join(root.path, 'pages', 'form', 'source.pdf#page=0'),
        );
        return (doc.id, id);
      }))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: kLocalizationsDelegates,
            supportedLocales: kSupportedLocales,
            home: ReviewScreen(docId: docId),
          ),
        ),
      );
      await settle(tester);
      expect(find.text(l10n.reviewPageOf(1, 1)), findsOneWidget);
      expect(find.byKey(ValueKey('crop-page-$pageId')), findsNothing);
    });
  });
}
