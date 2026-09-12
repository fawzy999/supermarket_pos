import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sale.dart';
import '../../../core/utils/format_utils.dart';

class InvoicePdfService {
  /// بيولّد ملف PDF للفاتورة ويرجع مساره على الجهاز
  Future<File> generate({
    required Sale sale,
    required List<Map<String, dynamic>> items,
    required Map<String, String?> storeSettings,
  }) async {
    // خطوط عربية (بتتحمل مرة واحدة وتتخزن محليًا بعد أول استخدام)
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final storeName = storeSettings['store_name'];
    final storePhone = storeSettings['store_phone'];
    final storeAddress = storeSettings['store_address'];
    final storeLogoPath = storeSettings['store_logo_path'];

    pw.MemoryImage? logoImage;
    if (storeLogoPath != null && File(storeLogoPath).existsSync()) {
      logoImage = pw.MemoryImage(File(storeLogoPath).readAsBytesSync());
    }

    final paymentLabel = switch (sale.paymentMethod) {
      'cash' => 'كاش',
      'card' => 'فيزا/بطاقة',
      'credit' => 'حساب عميل',
      'rep_account' => 'حساب مندوب',
      _ => 'فيزا/بطاقة',
    };
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Column(
                children: [
                  if (logoImage != null)
                    pw.Container(height: 60, width: 60, child: pw.Image(logoImage)),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    (storeName != null && storeName.trim().isNotEmpty) ? storeName : 'المحل',
                    style: pw.TextStyle(font: boldFont, fontSize: 20),
                  ),
                  if (storeAddress != null && storeAddress.trim().isNotEmpty) pw.Text(storeAddress),
                  if (storePhone != null && storePhone.trim().isNotEmpty) pw.Text(storePhone),
                ],
              ),
              pw.Divider(),
              pw.Text('فاتورة رقم: #${sale.id}'),
              pw.Text('التاريخ: ${sale.date.substring(0, 16).replaceFirst('T', ' ')}'),
              pw.Text('طريقة الدفع: $paymentLabel'),
              if (sale.customerName != null && sale.customerName!.trim().isNotEmpty)
                pw.Text('العميل: ${sale.customerName}'),
              if (sale.customerPhone != null && sale.customerPhone!.trim().isNotEmpty)
                pw.Text('تليفون العميل: ${sale.customerPhone}'),
              pw.Divider(),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(children: [
                    _cell('الصنف', boldFont),
                    _cell('كمية', boldFont),
                    _cell('سعر', boldFont),
                    _cell('إجمالي', boldFont),
                  ]),
                  for (final item in items)
                    pw.TableRow(children: [
                      _cell((item['product_name'] as String?) ?? '-', regularFont),
                      _cell(formatQuantity(item['quantity'] as num), regularFont),
                      _cell((item['unit_price'] as num).toStringAsFixed(2), regularFont),
                      _cell(
                        (((item['quantity'] as num) * (item['unit_price'] as num))).toStringAsFixed(2),
                        regularFont,
                      ),
                    ]),
                ],
              ),
              pw.Divider(),
              if (sale.discountPercent > 0) ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('الإجمالي قبل الخصم: ${sale.subtotalAmount.toStringAsFixed(2)} ج',
                      style: pw.TextStyle(font: regularFont)),
                ),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'الخصم (${formatQuantity(sale.discountPercent)}%): ${sale.discountAmount.toStringAsFixed(2)} ج',
                    style: pw.TextStyle(font: regularFont, color: PdfColors.orange),
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'الإجمالي: ${sale.totalAmount.toStringAsFixed(2)} ج',
                  style: pw.TextStyle(font: boldFont, fontSize: 16),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Center(child: pw.Text('شكرًا لتعاملكم معنا')),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/فاتورة_${sale.id}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  pw.Widget _cell(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, style: pw.TextStyle(font: font)),
      );
}
