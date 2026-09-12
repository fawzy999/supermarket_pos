import '../../database/app_database.dart';
import '../../modules_registry/module_definition.dart';

/// صلاحيات كل مستخدم (كاشير أو موظف) لكل موديول - فوق التفعيل العام
/// للموديول نفسه. الأدمن دايمًا شايف كل حاجة مرخّصة ومفعّلة، والتحكم
/// ده بيقصر الكاشير/الموظف على الموديولات اللي الأدمن سمحله بيها بس.
///
/// المنطق: لو مفيش صف صريح لمستخدم في موديول معين، الافتراضي إنه
/// "مسموح" (عشان الكاشير الحالي متتقفلش عليه موديولات فجأة بعد التحديث) -
/// الأدمن هو اللي بيقرر يمنع موديول معين عن مستخدم معين صراحةً.
class PermissionRepository {
  final _db = AppDatabase.instance;

  /// مفتاح صلاحية خاصة (مش موديول) بتُخزّن في نفس جدول user_permissions -
  /// صلاحية "استلام نقدية من الخزنة" (تسليم اليومية) للمدير/المحاسب.
  /// على عكس صلاحيات الموديولات، الافتراضي هنا "ممنوع" لأي حد غير الأدمن،
  /// والأدمن هو اللي يمنحها صراحةً لكاشير يثق فيه (يعمل دور "محاسب" عمليًا)
  static const permCashPickup = 'perm_cash_pickup';

  /// خريطة الصلاحيات الصريحة لمستخدم معين: module_key -> allowed
  Future<Map<String, bool>> getPermissionsForUser(int userId) async {
    final rows = await _db.database.query('user_permissions', where: 'user_id = ?', whereArgs: [userId]);
    return {for (final row in rows) row['module_key'] as String: (row['allowed'] as int) == 1};
  }

  Future<void> setPermission({required int userId, required String moduleKey, required bool allowed}) async {
    final existing = await _db.database.query(
      'user_permissions',
      where: 'user_id = ? AND module_key = ?',
      whereArgs: [userId, moduleKey],
    );
    if (existing.isEmpty) {
      await _db.database.insert('user_permissions', {
        'user_id': userId,
        'module_key': moduleKey,
        'allowed': allowed ? 1 : 0,
      });
    } else {
      await _db.database.update(
        'user_permissions',
        {'allowed': allowed ? 1 : 0},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  /// إزالة أي استثناء صريح - يرجّع المستخدم للسلوك الافتراضي (مسموح)
  Future<void> clearPermission({required int userId, required String moduleKey}) async {
    await _db.database.delete(
      'user_permissions',
      where: 'user_id = ? AND module_key = ?',
      whereArgs: [userId, moduleKey],
    );
  }

  /// بيفلتر قائمة الموديولات المتاحة (مرخّصة + مفعّلة) حسب صلاحيات
  /// مستخدم معين - يُستخدم في الشاشة الرئيسية للكاشير/الموظف
  Future<List<ModuleDefinition>> filterModulesForUser({
    required int userId,
    required bool isAdmin,
    required List<ModuleDefinition> activeModules,
  }) async {
    if (isAdmin) return activeModules;
    final permissions = await getPermissionsForUser(userId);
    return activeModules.where((m) => permissions[m.key] ?? true).toList();
  }

  /// هل المستخدم ده مسموحله يعمل "استلام نقدية من الخزنة"؟ الأدمن دايمًا
  /// مسموح، وأي حد تاني لازم يتمنحله الإذن ده صراحةً من لوحة التحكم
  Future<bool> canCollectCash({required int userId, required bool isAdmin}) async {
    if (isAdmin) return true;
    final permissions = await getPermissionsForUser(userId);
    return permissions[permCashPickup] ?? false;
  }
}
