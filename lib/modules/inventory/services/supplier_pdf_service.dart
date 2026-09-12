import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/supplier.dart';
import '../models/supplier_contact.dart';

/// بيولّد ملف PDF بكل بيانات المورد (بيانات الشركة + أشخاص التواصل +
/// آخر التوريدات)، بنفس أسلوب فاتورة البيع، عشان يتطبع/يتشارك/يتحفظ.
class SupplierPdfService {
  Future<File> generate({
    required Supplier supplier,
    required List<SupplierContact> contacts,
    required List<Map<String, dynamic>> recentBatches,
  }) async {
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pw.MemoryImage? logoImage;
    if (supplier.logoPath != null && File(supplier.logoPath!).existsSync()) {
      logoImage = pw.MemoryImage(File(supplier.logoPath!).readAsBytesSync());
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(height: 70, width: 70, child: pw.Image(logoImage)),
              pw.SizedBox(height: 6),
              pw.Text(supplier.companyName, style: pw.TextStyle(font: boldFont, fontSize: 20)),
            ],
          ),
          pw.Divider(),
          pw.Text('بيانات المورد', style: pw.TextStyle(font: boldFont, fontSize: 14)),
          pw.SizedBox(height: 6),
          if ((supplier.contactPerson ?? '').isNotEmpty) pw.Text('المسؤول الرئيسي: ${supplier.contactPerson}'),
          if ((supplier.phone ?? '').isNotEmpty) pw.Text('التليفون: ${supplier.phone}'),
          if ((supplier.email ?? '').isNotEmpty) pw.Text('الإيميل: ${supplier.email}'),
          if ((supplier.address ?? '').isNotEmpty) pw.Text('العنوان: ${supplier.address}'),
          if ((supplier.notes ?? '').isNotEmpty) pw.Text('ملاحظات: ${supplier.notes}'),
          pw.SizedBox(height: 16),
          if (contacts.isNotEmpty) ...[
            pw.Text('أشخاص التواصل', style: pw.TextStyle(font: boldFont, fontSize: 14)),
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
                  _cell('الاسم', boldFont),
                  _cell('الوظيفة', boldFont),
                  _cell('التليفون', boldFont),
                  _cell('الإيميل', boldFont),
                ]),
                for (final contact in contacts)
                  pw.TableRow(children: [
                    _cell(contact.name, regularFont),
                    _cell(contact.role ?? '', regularFont),
                    _cell(contact.phone ?? '', regularFont),
                    _cell(contact.email ?? '', regularFont),
                  ]),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
          if (recentBatches.isNotEmpty) ...[
            pw.Text('آخر التوريدات', style: pw.TextStyle(font: boldFont, fontSize: 14)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.5),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(children: [
                  _cell('الصنف', boldFont),
                  _cell('الكمية', boldFont),
                  _cell('تاريخ التوريد', boldFont),
                ]),
                for (final batch in recentBatches)
                  pw.TableRow(children: [
                    _cell(batch['product_name'] as String, regularFont),
                    _cell((batch['quantity_received'] as num).toStringAsFixed(0), regularFont),
                    _cell((batch['supply_date'] as String).substring(0, 10), regularFont),
                  ]),
              ],
            ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    // تنضيف اسم الشركة من أي رموز ممكن تبوّظ اسم الملف (زي / أو \)
    final safeName = supplier.companyName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    final file = File('${tempDir.path}/مورد_$safeName.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// بيولّد جدول PDF واحد بكل الموردين المسجلين وبياناتهم الأساسية،
  /// عشان يتطبع أو يتشارك أو يتحفظ كقائمة كاملة (مش مورد واحد بس).
  Future<File> generateList(List<Supplier> suppliers) async {
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) => [
          pw.Text('قائمة الموردين', style: pw.TextStyle(font: boldFont, fontSize: 20)),
          pw.Text('تاريخ الطباعة: ${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}'),
          pw.SizedBox(height: 6),
          pw.Text('عدد الموردين: ${suppliers.length}'),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(1.8),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(2.5),
            },
            children: [
              pw.TableRow(children: [
                _cell('اسم الشركة', boldFont),
                _cell('المسؤول', boldFont),
                _cell('التليفون', boldFont),
                _cell('الإيميل', boldFont),
                _cell('العنوان', boldFont),
              ]),
              for (final supplier in suppliers)
                pw.TableRow(children: [
                  _cell(supplier.companyName, regularFont),
                  _cell(supplier.contactPerson ?? '', regularFont),
                  _cell(supplier.phone ?? '', regularFont),
                  _cell(supplier.email ?? '', regularFont),
                  _cell(supplier.address ?? '', regularFont),
                ]),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/قائمة_الموردين_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  pw.Widget _cell(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, style: pw.TextStyle(font: font)),
      );
}
