import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

/// دايالوج توقيع رقمي بسيط (بالإصبع على الشاشة) - بيرجع مسار صورة PNG
/// للتوقيع المحفوظ، أو null لو المستخدم اختار "تخطي" (التوقيع اختياري
/// دايمًا - أي سند يتطبع من غير توقيع رقمي هيفضل فيه مكان توقيع فاضي
/// بالخط زي ما كان قبل كده).
class SignaturePadDialog {
  static Future<String?> show(BuildContext context, {required String title}) async {
    final controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 320,
          height: 200,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
            child: Signature(controller: controller, backgroundColor: Colors.grey.shade100),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('تخطي')),
          TextButton(onPressed: () => controller.clear(), child: const Text('مسح')),
          FilledButton(
            onPressed: () async {
              if (controller.isEmpty) {
                if (context.mounted) Navigator.pop(context, null);
                return;
              }
              final bytes = await controller.toPngBytes();
              if (bytes == null) {
                if (context.mounted) Navigator.pop(context, null);
                return;
              }
              final tempDir = await getTemporaryDirectory();
              final file = File('${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
              await file.writeAsBytes(bytes);
              if (context.mounted) Navigator.pop(context, file.path);
            },
            child: const Text('تم'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}
