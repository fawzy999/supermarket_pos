import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// اختيار مستند موحّد لكل شاشات رفع المستندات في التطبيق (المناديب،
/// الموظفين، الموردين، فواتير واستلامات التوريد): كاميرا، معرض الصور،
/// أو ملف PDF من مساحة تخزين الجهاز. بيرجع مسار الملف المختار أو null
/// لو المستخدم لغى.
///
/// نوع الملف (صورة أو PDF) بيتحدد وقت العرض من امتداد المسار نفسه
/// (انظر [isPdfPath])، فمفيش داعي لعمود إضافي في قاعدة البيانات.
class DocumentPicker {
  static Future<String?> pick(BuildContext context, {String pdfLabel = 'اختيار ملف PDF'}) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(pdfLabel),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return null;

    if (choice == 'pdf') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      return result?.files.single.path;
    }

    final picked = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1400,
    );
    return picked?.path;
  }
}

/// بيحدد لو المسار ده لملف PDF من امتداده - مفيش داعي لتخزين النوع
/// منفصل في قاعدة البيانات.
bool isPdfPath(String? path) => path != null && path.toLowerCase().endsWith('.pdf');
