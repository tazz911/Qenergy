// lib/features/analytics/report_pdf.dart
// Tracing sheet M6F1: build an energy report PDF for the period / zone chosen
// on the Analytics screen, then download / share it.
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/models.dart';
import '../../core/utils/format.dart';

class EnergyReportData {
  final String ownerName;
  final DateTime from, to; // `to` is exclusive (start of the next day)
  final String periodName;
  final String zoneName; // "All zones" or one zone
  final bool hourly;
  final List<UsageBucket> buckets;
  final List<({String name, double kwh})> zoneRows;
  final List<AlertModel> alerts;
  final Map<String, String> deviceZone; // deviceId → zone name

  EnergyReportData({required this.ownerName, required this.from, required this.to,
    required this.periodName, required this.zoneName, required this.hourly,
    required this.buckets, required this.zoneRows, required this.alerts, required this.deviceZone});
}

const _green = PdfColor.fromInt(0xFF00A884);
const _grey = PdfColor.fromInt(0xFF666666);
const _light = PdfColor.fromInt(0xFFF1F4F3);

Future<Uint8List> buildEnergyReport(EnergyReportData d, {pw.ThemeData? theme}) async {
  final doc = pw.Document(title: 'EnergyIQ Report', author: 'EnergyIQ', theme: theme);
  final dayFmt = DateFormat('d MMM yyyy');
  final last = d.to.subtract(const Duration(days: 1));
  final periodText = d.hourly ? dayFmt.format(d.from) : '${dayFmt.format(d.from)} - ${dayFmt.format(last)}';

  final total = d.buckets.fold(0.0, (s, b) => s + b.kwh);
  final peakKw = d.buckets.fold(0.0, (m, b) => b.maxPower > m ? b.maxPower : m) / 1000;
  final withV = d.buckets.where((b) => b.avgVoltage > 0).toList();
  final avgV = withV.isEmpty ? null : withV.fold(0.0, (s, b) => s + b.avgVoltage) / withV.length;
  final cost = total * tariffOmrPerKwh;
  final highAlerts = d.alerts.where((a) => a.severity == 'high').length;

  final usageRows = d.buckets.where((b) => b.kwh > 0 || b.maxPower > 0).map((b) => [
    d.hourly ? DateFormat('HH:00').format(b.bucket) : DateFormat('EEE d MMM').format(b.bucket),
    b.kwh.toStringAsFixed(3),
    (b.maxPower / 1000).toStringAsFixed(2),
    b.avgVoltage > 0 ? b.avgVoltage.toStringAsFixed(1) : '--',
    (b.kwh * tariffOmrPerKwh).toStringAsFixed(3),
  ]).toList();

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    header: (ctx) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _green, width: 2))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('EnergyIQ', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _green)),
        pw.Text('Energy Consumption Report', style: const pw.TextStyle(fontSize: 12, color: _grey)),
      ]),
    ),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Generated ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: _grey)),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _grey)),
    ]),
    build: (ctx) => [
      pw.SizedBox(height: 12),
      _info('Prepared for', d.ownerName),
      _info('Period', '${d.periodName}  ($periodText)'),
      _info('Zone', d.zoneName),
      pw.SizedBox(height: 16),

      _heading('Summary'),
      pw.Row(children: [
        _stat('Total energy', '${total.toStringAsFixed(2)} kWh'),
        _stat('Peak power', '${peakKw.toStringAsFixed(2)} kW'),
        _stat('Average voltage', avgV == null ? '--' : '${avgV.toStringAsFixed(1)} V'),
        _stat('Estimated cost', 'OMR ${cost.toStringAsFixed(3)}'),
        _stat('Alerts', '${d.alerts.length} ($highAlerts high)'),
      ]),
      pw.Text('Cost uses ${(tariffOmrPerKwh * 1000).toStringAsFixed(0)} baisa per kWh.',
          style: const pw.TextStyle(fontSize: 8, color: _grey)),
      pw.SizedBox(height: 16),

      if (d.zoneRows.isNotEmpty) ...[
        _heading('Usage by zone'),
        _table(['Zone', 'kWh', 'Share', 'Cost (OMR)'], d.zoneRows.map((z) => [
          z.name, z.kwh.toStringAsFixed(3),
          total == 0 ? '0%' : '${(z.kwh / total * 100).toStringAsFixed(1)}%',
          (z.kwh * tariffOmrPerKwh).toStringAsFixed(3),
        ]).toList()),
        pw.SizedBox(height: 16),
      ],

      _heading(d.hourly ? 'Hourly usage' : 'Daily usage'),
      usageRows.isEmpty
          ? pw.Text('No readings in this period.', style: const pw.TextStyle(fontSize: 10, color: _grey))
          : _table([d.hourly ? 'Hour' : 'Day', 'kWh', 'Peak kW', 'Avg V', 'Cost (OMR)'], usageRows),
      pw.SizedBox(height: 16),

      _heading('Alerts in this period'),
      d.alerts.isEmpty
          ? pw.Text('No alerts. Everything looked normal.', style: const pw.TextStyle(fontSize: 10, color: _grey))
          : _table(['Time', 'Zone', 'Type', 'Severity', 'Message', 'Status'], d.alerts.map((a) => [
              DateFormat('d MMM HH:mm').format(a.alertTime),
              d.deviceZone[a.deviceId] ?? '-',
              alertTitle(a.alertType),
              capitalize(a.severity),
              a.message,
              a.isAcknowledged ? 'Acknowledged' : 'Open',
            ]).toList()),
    ],
  ));
  return doc.save();
}

/// Opens the share sheet on phones, or downloads the file in the browser.
Future<void> shareEnergyReport(EnergyReportData d) async {
  final bytes = await buildEnergyReport(d, theme: await _unicodeTheme());
  final name = 'EnergyIQ_Report_${DateFormat('yyyy-MM-dd').format(d.from)}.pdf';
  await Printing.sharePdf(bytes: bytes, filename: name);
}

/// Noto Sans (+ Arabic) so names like "المطبخ" print correctly.
/// Needs internet the first time; falls back to the built-in font if offline.
Future<pw.ThemeData?> _unicodeTheme() async {
  try {
    final fonts = await Future.wait([
      PdfGoogleFonts.notoSansRegular(), PdfGoogleFonts.notoSansBold(), PdfGoogleFonts.notoSansArabicRegular(),
    ]).timeout(const Duration(seconds: 8));
    return pw.ThemeData.withFont(base: fonts[0], bold: fonts[1], fontFallback: [fonts[2]]);
  } catch (_) {
    return null;
  }
}

pw.Widget _heading(String t) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Text(t, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
);

pw.Widget _info(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 3),
  child: pw.Row(children: [
    pw.SizedBox(width: 80, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: _grey))),
    pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
  ]),
);

pw.Widget _stat(String label, String value) => pw.Expanded(
  child: pw.Container(
    margin: const pw.EdgeInsets.only(right: 6, bottom: 4),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(color: _light, borderRadius: pw.BorderRadius.circular(4)),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _grey)),
      pw.SizedBox(height: 2),
      pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
    ]),
  ),
);

pw.Widget _table(List<String> headers, List<List<String>> rows) => pw.TableHelper.fromTextArray(
  headers: headers,
  data: rows,
  headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
  headerDecoration: const pw.BoxDecoration(color: _green),
  cellStyle: const pw.TextStyle(fontSize: 9),
  oddRowDecoration: const pw.BoxDecoration(color: _light),
  cellAlignment: pw.Alignment.centerLeft,
  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
);
