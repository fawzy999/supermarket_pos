import 'package:flutter/material.dart';
import 'core/database/app_database.dart';
import 'app.dart';

Future<void> main() async {
  // لازم قبل أي استدعاء لـ plugins قبل runApp
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // تهيئة قاعدة البيانات المحلية وإنشاء كل الجداول لو أول مرة
    await AppDatabase.instance.initialize();
    runApp(const SupermarketPosApp());
  } catch (e) {
    // لو حصل أي خطأ في تهيئة قاعدة البيانات، نوري رسالة واضحة
    // بدل ما التطبيق يفضل شاشة سودة من غير أي تفسير
    runApp(_DatabaseErrorApp(error: e.toString()));
  }
}

class _DatabaseErrorApp extends StatelessWidget {
  final String error;
  const _DatabaseErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'حصل خطأ عند فتح قاعدة البيانات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
