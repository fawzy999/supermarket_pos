import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// إعدادات المحل بتتخزن في جدول settings العام (key-value)
/// المفاتيح المستخدمة: store_name, store_phone, store_address, store_logo_path
class StoreSettingsRepository {
  final _db = AppDatabase.instance;

  Future<Map<String, String?>> getSettings() async {
    final rows = await _db.database.query('settings');
    final map = {for (final row in rows) row['key'] as String: row['value'] as String?};
    return {
      'store_name': map['store_name'],
      'store_phone': map['store_phone'],
      'store_address': map['store_address'],
      'store_logo_path': map['store_logo_path'],
    };
  }

  Future<void> setSetting(String key, String? value) async {
    await _db.database.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
