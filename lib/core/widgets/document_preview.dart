import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../utils/document_picker.dart';

/// معاينة مصغّرة لمستند (صورة أو PDF) - تُستخدم في كل شبكات/قوائم
/// المستندات بالتطبيق بدل تكرار نفس منطق "صورة أو أيقونة معطوبة" في كل
/// شاشة. الضغط عليها بيفتح المستند كامل: الصور في معاينة مكبّرة، وملفات
/// الـ PDF في شاشة معاينة/طباعة (نفس الآلية المستخدمة في فواتير البيع).
/// فتح مستند (صورة أو PDF) كامل - صورة في معاينة مكبّرة، وPDF في شاشة
/// معاينة/طباعة. مستخدمة في أي مكان بالتطبيق يعرض مستند برفرنس مباشر
/// للمسار (زي صور فاتورة/استلام التوريد في بروفايل المورد).
Future<void> openDocumentFile(BuildContext context, String path) async {
  if (isPdfPath(path)) {
    await Printing.layoutPdf(onLayout: (_) async => File(path).readAsBytesSync());
    return;
  }
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: InteractiveViewer(child: Image.file(File(path))),
    ),
  );
}

class DocumentPreview extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const DocumentPreview({super.key, required this.path, this.fit = BoxFit.cover});

  Future<void> _open(BuildContext context) => openDocumentFile(context, path);

  @override
  Widget build(BuildContext context) {
    final exists = File(path).existsSync();
    final isPdf = isPdfPath(path);

    Widget content;
    if (!exists) {
      content = const Center(child: Icon(Icons.broken_image_outlined));
    } else if (isPdf) {
      content = Container(
        color: Colors.red.shade50,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined, color: Colors.red, size: 36),
            SizedBox(height: 4),
            Text('PDF', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else {
      content = Image.file(File(path), fit: fit, width: double.infinity);
    }

    return InkWell(onTap: exists ? () => _open(context) : null, child: content);
  }
}

/// نسخة صغيرة (Thumbnail مربّع) بتتستخدم في القوائم اللي بتعرض المستند
/// كأيقونة/معاينة صغيرة جنب اسمه (زي "فاتورة المورد" في شاشة التوريد).
class DocumentLeadingThumbnail extends StatelessWidget {
  final String? path;
  final double size;

  const DocumentLeadingThumbnail({super.key, required this.path, this.size = 44});

  @override
  Widget build(BuildContext context) {
    if (path == null) return Icon(Icons.receipt_long_outlined, size: size * 0.7);
    if (isPdfPath(path)) {
      return SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
      );
    }
    if (!File(path!).existsSync()) return Icon(Icons.broken_image_outlined, size: size * 0.7);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(File(path!), width: size, height: size, fit: BoxFit.cover),
    );
  }
}
