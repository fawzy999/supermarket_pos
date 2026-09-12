import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/expense.dart';

/// بيولّد تقرير PDF لملخص الحسابات (إيراد/ربح اليوم والشهر، مبيعات كل
/// كاشير، والمصروفات)، عشان يتطبع/يتشارك/يتحفظ زي فاتورة البيع بالظبط.
class AccountingReportPdfService {
  Future<File> generate({
    required double todayRevenue,
    required double todayProfit,
    required double monthRevenue,
    required double monthProfit,
    required double monthExpenses,
    required List<Map<String, dynamic>> cashierRevenue,
    required List<Expense> expenses,
    String? storeName,
  }) async {
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final netThisMonth = monthProfit - monthExpenses;

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) => [
          pw.Text(
            (storeName != null && storeName.trim().isNotEmpty) ? storeName : 'تقرير الحسابات',
            style: pw.TextStyle(font: boldFont, fontSize: 20),
          ),
          pw.Text('تاريخ التقرير: ${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}'),
          pw.Divider(),
          pw.Text('اليوم', style: pw.TextStyle(font: boldFont, fontSize: 14)),
          pw.Text('إجمالي المبيعات: ${todayRevenue.toStringAsFixed(2)} ج'),
          pw.Text('صافي الربح التقريبي: ${todayProfit.toStringAsFixed(2)} ج'),
          pw.SizedBox(height: 12),
          pw.Text('الشهر الحالي', style: pw.TextStyle(font: boldFont, fontSize: 14)),
          pw.Text('إجمالي المبيعات: ${monthRevenue.toStringAsFixed(2)} ج'),
          pw.Text('إجمالي الربح من المبيعات: ${monthProfit.toStringAsFixed(2)} ج'),
          pw.Text('إجمالي المصروفات: ${monthExpenses.toStringAsFixed(2)} ج'),
          pw.Text(
            'صافي الربح بعد المصروفات: ${netThisMonth.toStringAsFixed(2)} ج',
            style: pw.TextStyle(font: boldFont),
          ),
          pw.SizedBox(height: 16),
          if (cashierRevenue.isNotEmpty) ...[
            pw.Text('مبيعات كل كاشير هذا الشهر', style: pw.TextStyle(font: boldFont, fontSize: 14)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(children: [_cell('الكاشير', boldFont), _cell('الإجمالي', boldFont)]),
                for (final row in cashierRevenue)
                  pw.TableRow(children: [
                    _cell(row['cashier_name'] as String, regularFont),
                    _cell((row['total'] as num).toStringAsFixed(2), regularFont),
                  ]),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
          if (expenses.isNotEmpty) ...[
            pw.Text('المصروفات هذا الشهر', style: pw.TextStyle(font: boldFont, fontSize: 14)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.5),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(children: [_cell('البيان', boldFont), _cell('المبلغ', boldFont), _cell('التاريخ', boldFont)]),
                for (final expense in expenses)
                  pw.TableRow(children: [
                    _cell(expense.description, regularFont),
                    _cell(expense.amount.toStringAsFixed(2), regularFont),
                    _cell(expense.date.substring(0, 10), regularFont),
                  ]),
              ],
            ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/تقرير_الحسابات_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  pw.Widget _cell(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, style: pw.TextStyle(font: font)),
      );
}
