import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// إعدادات عامة إضافية (غير بيانات المحل الأساسية) بتتخزن في نفس
/// جدول settings العام (key-value) - مستخدمة لإعدادات المدير
/// (للتقارير والتذكيرات)، بيانات SMTP للإيميل، ومفتاح الذكاء
/// الاصطناعي. كل مفتاح جديد ممكن يتضاف من غير أي تعديل في قاعدة
/// البيانات لأن الجدول عام أصلًا.
class AppSettingsRepository {
  final _db = AppDatabase.instance;

  static const keyManagerName = 'manager_name';
  static const keyManagerPhone = 'manager_phone';
  static const keyManagerEmail = 'manager_email';
  static const keySmtpHost = 'smtp_host';
  static const keySmtpPort = 'smtp_port';
  static const keySmtpUsername = 'smtp_username';
  static const keySmtpPassword = 'smtp_password';
  static const keyAiApiKey = 'ai_api_key';
  static const keyAiModel = 'ai_model';
  static const keyDiscountEnabled = 'discount_enabled';
  static const keyMaxDiscountPercent = 'max_discount_percent';
  static const keyMandatoryClosingEnabled = 'mandatory_closing_enabled';
  static const keyMandatoryClosingHours = 'mandatory_closing_hours';
  static const keyScanSoundEnabled = 'scan_sound_enabled';
  static const keyScanSoundVolume = 'scan_sound_volume'; // 0.0 - 1.0

  Future<Map<String, String?>> getAll(List<String> keys) async {
    final rows = await _db.database.query('settings');
    final map = {for (final row in rows) row['key'] as String: row['value'] as String?};
    return {for (final key in keys) key: map[key]};
  }

  Future<String?> get(String key) async {
    final rows = await _db.database.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String? value) async {
    await _db.database.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
