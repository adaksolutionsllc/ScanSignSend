import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One page for Send → Text or Word: the words printed on it, and what the
/// user filled in. Signatures are pictures and are left out.
class TextExportPage {
  const TextExportPage({required this.text, this.filled = const []});

  /// The page's own text (PDF text layer or OCR); may be empty.
  final String text;

  /// "Label: value" lines for the fields filled on this page.
  final List<String> filled;

  bool get isEmpty => text.isEmpty && filled.isEmpty;
}

/// Send → Text: pages in order, each under a "— [heading] —" line, so the
/// reader can tell where a page starts.
String buildTxt(List<TextExportPage> pages, String Function(int) heading) {
  final out = StringBuffer();
  for (final (i, page) in pages.indexed) {
    if (page.isEmpty) continue;
    if (out.isNotEmpty) out.write('\n\n');
    out.writeln('— ${heading(i + 1)} —');
    if (page.text.isNotEmpty) out.writeln(page.text);
    if (page.filled.isNotEmpty) {
      if (page.text.isNotEmpty) out.writeln();
      out.writeln(page.filled.join('\n'));
    }
  }
  return out.toString().trimRight();
}

/// Send → Word: a .docx with one heading per page and a page break between
/// pages. Text only; Word, Pages and Google Docs open it.
///
/// A .docx is a zip of XML parts; only the four that every reader needs are
/// written.
Uint8List buildDocx(
  String title,
  List<TextExportPage> pages,
  String Function(int) heading,
) {
  final body = StringBuffer();
  var first = true;
  for (final (i, page) in pages.indexed) {
    if (page.isEmpty) continue;
    body.write(
      _paragraph(heading(i + 1), style: 'Heading1', pageBreak: !first),
    );
    first = false;
    for (final line in page.text.split('\n')) {
      body.write(_paragraph(line));
    }
    if (page.filled.isNotEmpty && page.text.isNotEmpty) {
      body.write(_paragraph(''));
    }
    for (final line in page.filled) {
      body.write(_paragraph(line));
    }
  }
  if (first) body.write(_paragraph(''));

  final archive = Archive();
  void add(String name, String xml) {
    final bytes = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', _contentTypes);
  add('_rels/.rels', _rels);
  add('word/_rels/document.xml.rels', _documentRels);
  add('word/styles.xml', _styles);
  add('docProps/core.xml', _core(title));
  add(
    'word/document.xml',
    '$_xmlHead<w:document xmlns:w="$_w"><w:body>$body'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>'
        '</w:sectPr></w:body></w:document>',
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _paragraph(String text, {String? style, bool pageBreak = false}) {
  final props = style == null
      ? ''
      : '<w:pPr><w:pStyle w:val="$style"/></w:pPr>';
  final brk = pageBreak ? '<w:r><w:br w:type="page"/></w:r>' : '';
  final run = text.isEmpty
      ? ''
      : '<w:r><w:t xml:space="preserve">${_escape(text)}</w:t></w:r>';
  return '<w:p>$props$brk$run</w:p>';
}

/// XML-escaped, without the control characters XML 1.0 forbids (OCR can
/// return them).
String _escape(String s) => s
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const _xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _pkgRel = 'http://schemas.openxmlformats.org/package/2006/relationships';
const _offRel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

const _contentTypes =
    '$_xmlHead<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '</Types>';

const _rels =
    '$_xmlHead<Relationships xmlns="$_pkgRel">'
    '<Relationship Id="rId1" Type="$_offRel/officeDocument" Target="word/document.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '</Relationships>';

const _documentRels =
    '$_xmlHead<Relationships xmlns="$_pkgRel">'
    '<Relationship Id="rId1" Type="$_offRel/styles" Target="styles.xml"/>'
    '</Relationships>';

const _styles =
    '$_xmlHead<w:styles xmlns:w="$_w">'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
    '<w:name w:val="Normal"/><w:pPr><w:spacing w:after="120"/></w:pPr>'
    '<w:rPr><w:sz w:val="22"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading1">'
    '<w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>'
    '<w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="240" w:after="120"/>'
    '<w:outlineLvl w:val="0"/></w:pPr>'
    '<w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>'
    '</w:styles>';

String _core(String title) =>
    '$_xmlHead<cp:coreProperties '
    'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/">'
    '<dc:title>${_escape(title)}</dc:title></cp:coreProperties>';
