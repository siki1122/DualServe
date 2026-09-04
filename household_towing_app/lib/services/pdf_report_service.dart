import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class PdfReportService {
  static Future<void> generateAndDownloadReport({
    required int totalCustomers,
    required double monthlyRevenue,
    required String avgResponseTime,
    required String averageRating,
  }) async {
    final pdf = pw.Document();
    
    final now = DateTime.now();
    final formattedDate = DateFormat('MMMM dd, yyyy - hh:mm a').format(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('DualServe Admin Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Generated: $formattedDate', style: const pw.TextStyle(fontSize: 12, color: PdfAppTheme.textSlateMedium)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 32),
                
                pw.Text('Executive Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    children: [
                      _buildMetricRow('Total Customers', totalCustomers.toString()),
                      pw.Divider(color: PdfColors.grey300),
                      _buildMetricRow('Monthly Revenue', 'PHP ${monthlyRevenue.toStringAsFixed(2)}'),
                      pw.Divider(color: PdfColors.grey300),
                      _buildMetricRow('Avg Response Time', avgResponseTime),
                      pw.Divider(color: PdfColors.grey300),
                      _buildMetricRow('Average Rating', averageRating),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 48),
                pw.Text('Detailed metrics and charts can be viewed interactively in the DualServe Admin Dashboard.', 
                    style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'DualServe_Report_${DateFormat('yyyyMMdd').format(now)}.pdf',
    );
  }

  static pw.Widget _buildMetricRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 14)),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
