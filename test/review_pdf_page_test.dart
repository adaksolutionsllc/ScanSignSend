// Review draws an imported PDF page on white: many PDFs paint no background,
// and in dark mode their black text sat on the dark card (1.3.1, TestFlight).

import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan_sign_send/core/db/app_database.dart' hide Page;
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/page_raster_service.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/review/presentation/review_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRaster extends PageRasterService {
  _FakeRaster(this.path);
  final String path;

  @override
  Future<String> imageFor(String storedPath) async => path;
}

void main() {
  testWidgets('a PDF page is drawn on white, in dark mode too', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);
    final tmp = Directory.systemTemp.createTempSync('review_pdf_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    // A render with no background: transparent, as PDFKit gives it.
    final png = File('${tmp.path}/page.png')
      ..writeAsBytesSync(
        img.encodePng(img.Image(width: 8, height: 10, numChannels: 4)),
      );

    final docId = (await tester.runAsync(() async {
      final doc = await DocumentRepository(db).createDocument('Form');
      await PageRepository(db).addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: '/missing/form.pdf#page=0',
      );
      return doc.id;
    }))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pageRasterServiceProvider.overrideWithValue(_FakeRaster(png.path)),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: ReviewScreen(docId: docId),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    final page = tester.widget<Image>(
      find.byKey(const ValueKey('review-pdf-page')),
    );
    expect(page.color, Colors.white);
    expect(page.colorBlendMode, BlendMode.dstOver);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
