// Send → Text and Word (F2): page text and filled-in values, one heading per
// page; the .docx is a valid zip with the parts Word needs.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/services/text_export.dart';

String heading(int n) => 'Page $n';

const pages = [
  TextExportPage(
    text: 'Lease agreement\nRent & deposit <due>',
    filled: ['Tenant name: Jane Doe'],
  ),
  TextExportPage(text: ''),
  TextExportPage(text: '', filled: ['Agree: ☑']),
];

void main() {
  test('Text: a heading per page, empty pages left out', () {
    expect(
      buildTxt(pages, heading),
      '— Page 1 —\n'
      'Lease agreement\n'
      'Rent & deposit <due>\n'
      '\n'
      'Tenant name: Jane Doe\n'
      '\n'
      '\n'
      '— Page 3 —\n'
      'Agree: ☑',
    );
    expect(buildTxt(const [TextExportPage(text: '')], heading), isEmpty);
  });

  test('Word: a zip with the parts Word needs, text escaped', () {
    final bytes = buildDocx('Lease & co', pages, heading);
    final zip = ZipDecoder().decodeBytes(bytes);
    expect(
      zip.files.map((f) => f.name).toSet(),
      containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'word/document.xml',
        'word/styles.xml',
        'word/_rels/document.xml.rels',
      ]),
    );
    String part(String name) =>
        utf8.decode(zip.findFile(name)!.content as List<int>);
    final doc = part('word/document.xml');
    expect(doc, contains('Rent &amp; deposit &lt;due&gt;'));
    expect(doc, contains('Tenant name: Jane Doe'));
    expect(doc, isNot(contains('Page 2')), reason: 'an empty page is left out');
    // Two headings, and a page break before the second only.
    expect('w:val="Heading1"'.allMatches(doc), hasLength(2));
    expect('w:type="page"'.allMatches(doc), hasLength(1));
    expect(part('docProps/core.xml'), contains('Lease &amp; co'));

    final dir = Platform.environment['TEXT_EXPORT_OUT'];
    if (dir != null) File('$dir/sample.docx').writeAsBytesSync(bytes);
  });

  test('Word: control characters from OCR are dropped', () {
    final doc = utf8.decode(
      ZipDecoder()
              .decodeBytes(
                buildDocx('x', const [
                  TextExportPage(text: 'a\x0Bb\x01c'),
                ], heading),
              )
              .findFile('word/document.xml')!
              .content
          as List<int>,
    );
    expect(doc, contains('>abc<'));
  });
}
