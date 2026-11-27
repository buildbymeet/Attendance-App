import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'ui.dart';

class ReportTable {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  const ReportTable(this.title, this.columns, this.rows);
}

String _csvCell(String s) => (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;

String toCsv(ReportTable t) => '﻿${[t.columns, ...t.rows].map((r) => r.map(_csvCell).join(',')).join('\r\n')}';

/// Writes a UTF-8 CSV (opens directly in Excel) and opens the share sheet.
Future<void> shareCsv(BuildContext c, ReportTable t) async {
  try {
    final dir = await getTemporaryDirectory();
    final name = '${t.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}.csv';
    final f = File('${dir.path}/$name');
    await f.writeAsString(toCsv(t));
    await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')], subject: t.title);
  } catch (e) {
    if (c.mounted) toast(c, 'Export failed: $e', error: true);
  }
}

Future<void> printTable(BuildContext c, ReportTable t) async {
  try {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: pw.Text(t.title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
      build: (_) => [
        pw.TableHelper.fromTextArray(
          headers: t.columns,
          data: t.rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellPadding: const pw.EdgeInsets.all(3),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: t.title);
  } catch (e) {
    if (c.mounted) toast(c, 'Print failed: $e', error: true);
  }
}
