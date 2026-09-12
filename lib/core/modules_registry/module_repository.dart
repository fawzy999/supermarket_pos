import '../database/app_database.dart';
import 'module_definition.dart';

/// المسؤول عن تحديد: أنهي موديولات فعليًا لازم تظهر للمستخدم؟
///
/// موديول بيظهر بس لو:
/// 1. مرخّص للعميل ده (licensed_modules.is_licensed = 1)
/// 2. ومفعّل تشغيليًا من الأدمن (modules_settings.is_enabled = 1)
class ModuleRepository {
  final _db = AppDatabase.instance;

  /// بترجع الموديولات اللي المفروض تظهر في الشاشة الرئيسية
  Future<List<ModuleDefinition>> getActiveModules(
    List<ModuleDefinition> registeredModules,
  ) async {
    final licensedRows = await _db.database.query(
      'licensed_modules',
      where: 'is_licensed = 1',
    );
    final enabledRows = await _db.database.query(
      'modules_settings',
      where: 'is_enabled = 1',
    );

    final licensedKeys = licensedRows.map((r) => r['module_key'] as String).toSet();
    final enabledKeys = enabledRows.map((r) => r['module_key'] as String).toSet();

    return registeredModules
        .where((m) => licensedKeys.contains(m.key) && enabledKeys.contains(m.key))
        .toList();
  }

  /// بيرجع حالة كل الموديولات (لاستخدامها في داشبورد الأدمن)
  /// بيرجع Map: module_key -> {is_licensed, is_enabled}
  Future<Map<String, Map<String, bool>>> getAllModulesStatus() async {
    final licensedRows = await _db.database.query('licensed_modules');
    final enabledRows = await _db.database.query('modules_settings');

    final licensedMap = {
      for (final row in licensedRows)
        row['module_key'] as String: (row['is_licensed'] as int) == 1,
    };
    final enabledMap = {
      for (final row in enabledRows)
        row['module_key'] as String: (row['is_enabled'] as int) == 1,
    };

    final allKeys = {...licensedMap.keys, ...enabledMap.keys};
    return {
      for (final key in allKeys)
        key: {
          'is_licensed': licensedMap[key] ?? false,
          'is_enabled': enabledMap[key] ?? false,
        },
    };
  }

  /// تفعيل أو تعطيل موديول - بيستخدمها الأدمن بس
  /// ملحوظة: لازم نتحقق إن الموديول مرخّص أصلاً قبل ما نسمح بتفعيله
  Future<void> setModuleEnabled(String moduleKey, bool enabled) async {
    await _db.database.update(
      'modules_settings',
      {
        'is_enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'module_key = ?',
      whereArgs: [moduleKey],
    );
  }
}
