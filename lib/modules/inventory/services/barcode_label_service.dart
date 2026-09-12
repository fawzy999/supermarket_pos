import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';
import 'package:printing/printing.dart';
import '../models/product.dart';

class BarcodeLabelService {
  Future<File> generateLabel(Product product) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final doc = pw.Document();

    // حجم ملصق صغير قياسي (زي ملصقات السوبر ماركت العادية)
    final labelFormat = PdfPageFormat(8 * PdfPageFormat.cm, 4 * PdfPageFormat.cm);

    doc.addPage(
      pw.Page(
        pageFormat: labelFormat,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                product.name,
                style: pw.TextStyle(font: boldFont, fontSize: 12),
                textAlign: pw.TextAlign.center,
                textDirection: pw.TextDirection.rtl,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${product.salePrice.toStringAsFixed(2)} ج',
                style: pw.TextStyle(font: boldFont, fontSize: 14),
              ),
              pw.SizedBox(height: 6),
              pw.BarcodeWidget(
                barcode: Barcode.ean13(),
                data: product.barcode ?? '',
                width: 160,
                height: 50,
                drawText: true,
                textStyle: pw.TextStyle(font: font, fontSize: 9),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/ملصق_${product.barcode}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
