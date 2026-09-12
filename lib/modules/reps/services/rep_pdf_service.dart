import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/rep.dart';

/// بيولّد كشف حساب PDF كامل لمندوب: بياناته، رصيد العهدة الحالي،
/// ملخص المبيعات والتحصيل والتوصيل - عشان يتطبع/يتشارك/يتحفظ زي أي
/// تقرير تاني في التطبيق.
class RepPdfService {
  Future<File> generateStatement({
    required Rep rep,
    required List<Map<String, dynamic>> custodyBalance,
    required Map<String, dynamic> performance,
    required List<Map<String, dynamic>> recentSales,
  }) async {
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) => [
          pw.Text(rep.name, style: pw.TextStyle(font: boldFont, fontSize: 20)),
          pw.Text('تاريخ الكشف: ${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}'),
          pw.Divider(),
          if ((rep.phone ?? '').isNotEmpty) pw.Text('التليفون: ${rep.phone}'),
          if ((rep.nationalId ?? '').isNotEmpty) pw.Text('الرقم القومي: ${rep.nationalId}'),
          if ((rep.address ?? '').isNotEmpty) pw.Text('العنوان: ${rep.address}'),
          pw.SizedBox(height: 16),

          pw.Text('ملخص الأداء', style: pw.TextStyle(font: boldFont, fontSize: 14)),
          pw.SizedBox(height: 6),
          pw.Text('عدد فواتير البيع الخارجي: ${performance['sales_count']}'),
          pw.Text('إجمالي مبيعاته: ${(performance['sales_total'] as num).toStringAsFixed(2)} ج'),
          pw.Text('إجمالي ما حصّله من العملاء: ${(performance['collections_total'] as num).toStringAsFixed(2)} ج'),
          pw.Text('إجمالي مبيعات آجلة (مديونية عملاء): ${(performance['credit_sales_total'] as num).toStringAsFixed(2)} ج'),
          pw.Text('طلبات توصيل مكتملة: ${performance['delivered_count']}'),
          pw.Text('طلبات توصيل معلّقة: ${performance['pending_deliveries_count']}'),
          pw.SizedBox(height: 16),

          if (custodyBalance.isNotEmpty) ...[
            pw.Text('رصيد العهدة الحالي', style: pw.TextStyle(font: boldFont, fontSize: 14)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(children: [_cell('الصنف', boldFont), _cell('الكمية المتبقية معه', boldFont)]),
                for (final row in custodyBalance)
                  pw.TableRow(children: [
                    _cell(row['product_name'] as String, regularFont),
                    _cell((row['remaining'] as num).toStringAsFixed(0), regularFont),
                  ]),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          if (recentSales.isNotEmpty) ...[
            pw.Text('آخر فواتير البيع الخارجي', style: pw.TextStyle(font: boldFont, fontSize: 14)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(children: [
                  _cell('العميل', boldFont),
                  _cell('الإجمالي', boldFont),
                  _cell('طريقة الدفع', boldFont),
                  _cell('التاريخ', boldFont),
                ]),
                for (final sale in recentSales)
                  pw.TableRow(children: [
                    _cell((sale['customer_name'] as String?) ?? '-', regularFont),
                    _cell((sale['total_amount'] as num).toStringAsFixed(2), regularFont),
                    _cell(sale['payment_method'] == 'credit' ? 'آجل' : 'كاش', regularFont),
                    _cell((sale['date'] as String).substring(0, 10), regularFont),
                  ]),
              ],
            ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    final safeName = rep.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    final file = File('${tempDir.path}/كشف_حساب_مندوب_$safeName.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  pw.Widget _cell(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, style: pw.TextStyle(font: font)),
      );

  /// سند صرف/استلام عهدة: مستند رسمي بيوثّق عملية سحب بضاعة لعهدة المندوب
  /// أو إرجاعها للمخزون - زي أي إذن صرف/استلام في شركة شحن حقيقية،
  /// بيتطبع أو يتشارك أو يتحفظ فور تسجيل الحركة.
  Future<File> generateCustodyVoucher({
    required Rep rep,
    required String type, // withdraw / return
    required String productName,
    required double quantity,
    required String unit,
    required String date,
    String? receivedBy,
    String? storeName,
    String? repSignaturePath,
    String? receiverSignaturePath,
  }) async {
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final isWithdraw = type == 'withdraw';
    final title = isWithdraw ? 'سند صرف عهدة لمندوب' : 'سند استلام عهدة من مندوب';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if ((storeName ?? '').isNotEmpty)
              pw.Text(storeName!, style: pw.TextStyle(font: boldFont, fontSize: 16)),
            pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 20)),
            pw.SizedBox(height: 4),
            pw.Text('التاريخ: ${date.substring(0, 16).replaceFirst('T', ' ')}'),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('اسم المندوب: ${rep.name}', style: const pw.TextStyle(fontSize: 14)),
            if ((rep.nationalId ?? '').isNotEmpty)
              pw.Text('الرقم القومي: ${rep.nationalId}', style: const pw.TextStyle(fontSize: 14)),
            if ((rep.phone ?? '').isNotEmpty)
              pw.Text('التليفون: ${rep.phone}', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(children: [_cell('الصنف', boldFont), _cell('الكمية', boldFont), _cell('نوع الحركة', boldFont)]),
                pw.TableRow(children: [
                  _cell(productName, regularFont),
                  _cell('${quantity.toStringAsFixed(0)} $unit', regularFont),
                  _cell(isWithdraw ? 'صرف من المخزون لعهدة المندوب' : 'استلام من المندوب للمخزون', regularFont),
                ]),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('توقيع المندوب'),
                    pw.SizedBox(height: 4),
                    _signatureOrLine(repSignaturePath),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('استلمه بمعرفة: ${receivedBy ?? '..........................'}'),
                    pw.SizedBox(height: 4),
                    _signatureOrLine(receiverSignaturePath),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    final safeName = rep.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/سند_عهدة_${safeName}_$stamp.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// سند تسوية دورية لعهدة المندوب - بيوثّق تسليم المبلغ النقدي المُسلَّم
  /// وأي تسوية جرد حصلت، بنفس منطق سند الصرف/الاستلام
  Future<File> generateSettlementVoucher({
    required Rep rep,
    required double amountSettled,
    required String date,
    String? notes,
    String? settledBy,
    String? storeName,
    String? repSignaturePath,
    String? receiverSignaturePath,
  }) async {
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if ((storeName ?? '').isNotEmpty)
              pw.Text(storeName!, style: pw.TextStyle(font: boldFont, fontSize: 16)),
            pw.Text('سند تسوية دورية لعهدة مندوب', style: pw.TextStyle(font: boldFont, fontSize: 20)),
            pw.SizedBox(height: 4),
            pw.Text('التاريخ: ${date.substring(0, 16).replaceFirst('T', ' ')}'),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('اسم المندوب: ${rep.name}', style: const pw.TextStyle(fontSize: 14)),
            if ((rep.nationalId ?? '').isNotEmpty)
              pw.Text('الرقم القومي: ${rep.nationalId}', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 12),
            pw.Text('المبلغ النقدي المُسلَّم: ${amountSettled.toStringAsFixed(2)} ج',
                style: pw.TextStyle(font: boldFont, fontSize: 16)),
            if ((notes ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('ملاحظات: $notes'),
            ],
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('توقيع المندوب'),
                    pw.SizedBox(height: 4),
                    _signatureOrLine(repSignaturePath),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('استلمه بمعرفة: ${settledBy ?? '..........................'}'),
                    pw.SizedBox(height: 4),
                    _signatureOrLine(receiverSignaturePath),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    final safeName = rep.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/سند_تسوية_${safeName}_$stamp.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// بيرجّع صورة التوقيع لو موجودة وصالحة، وإلا مكان توقيع فاضي بالخط
  pw.Widget _signatureOrLine(String? signaturePath) {
    if (signaturePath != null && File(signaturePath).existsSync()) {
      return pw.Container(
        width: 120,
        height: 50,
        child: pw.Image(pw.MemoryImage(File(signaturePath).readAsBytesSync())),
      );
    }
    return pw.Text('..........................');
  }
}
