import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/format_utils.dart';

/// توليد PDF احترافي لطلب توريد/شراء: شعار وبيانات المحل، بيانات
/// المورد كاملة، جدول الأصناف والكميات والأسعار - بنفس شكل فاتورة
/// البيع تمامًا عشان يكون احترافي وموحّد الشكل مع باقي مطبوعات المحل.
class PurchaseOrderPdfService {
  Future<File> generate({
    required Map<String, dynamic> order,
    required List<Map<String, dynamic>> items,
    required Map<String, String?> storeSettings,
    String? managerName,
  }) async {
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

    final totalAmount = (order['total_amount'] as num).toDouble();
    final date = (order['date'] as String).substring(0, 16).replaceFirst('T', ' ');

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
              pw.Text('طلب توريد رقم: #${order['id']}', style: pw.TextStyle(font: boldFont, fontSize: 16)),
              pw.Text('التاريخ: $date'),
              if (managerName != null && managerName.trim().isNotEmpty)
                pw.Text('المدير المسؤول: $managerName'),
              pw.Divider(),
              pw.Text('بيانات المورد', style: pw.TextStyle(font: boldFont)),
              pw.Text('الاسم: ${order['supplier_name'] ?? '-'}'),
              if ((order['supplier_phone'] as String?)?.trim().isNotEmpty ?? false)
                pw.Text('التليفون: ${order['supplier_phone']}'),
              if ((order['supplier_email'] as String?)?.trim().isNotEmpty ?? false)
                pw.Text('الإيميل: ${order['supplier_email']}'),
              if ((order['supplier_address'] as String?)?.trim().isNotEmpty ?? false)
                pw.Text('العنوان: ${order['supplier_address']}'),
              pw.Divider(),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.5),
                  4: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(children: [
                    _cell('الصنف', boldFont),
                    _cell('الوحدة', boldFont),
                    _cell('الكمية', boldFont),
                    _cell('السعر', boldFont),
                    _cell('الإجمالي', boldFont),
                  ]),
                  for (final item in items)
                    pw.TableRow(children: [
                      _cell(item['item_name'] as String, regularFont),
                      _cell((item['unit'] as String?) ?? '-', regularFont),
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
              if ((order['notes'] as String?)?.trim().isNotEmpty ?? false) ...[
                pw.Text('ملاحظات: ${order['notes']}'),
                pw.SizedBox(height: 6),
              ],
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'الإجمالي: ${totalAmount.toStringAsFixed(2)} ج',
                  style: pw.TextStyle(font: boldFont, fontSize: 16),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Center(child: pw.Text('برجاء تأكيد الطلب والموعد المتوقع للتوريد')),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/طلب_توريد_${order['id']}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  pw.Widget _cell(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, style: pw.TextStyle(font: font)),
      );
}
