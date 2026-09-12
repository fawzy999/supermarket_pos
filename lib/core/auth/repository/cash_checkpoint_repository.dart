import '../../database/app_database.dart';

/// نقاط "استلام نقدية من الخزنة" اللي بيعملها المدير أو المحاسب - مختلفة
/// عن تسليم العهدة بين الكاشيرين: هنا الكاش الفعلي بيتاخد من الدرج (مثلاً
/// عشان يورّد في البنك)، فالرصيد المتوقع في الدرج بيرجع لصفر من نفس اللحظة.
class CashCheckpointRepository {
  final _db = AppDatabase.instance;

  /// وقت آخر نقطة استلام مسجّلة (لو مفيش، null)
  Future<DateTime?> getLastCheckpointTime() async {
    final rows = await _db.database.rawQuery('SELECT MAX(at) as last FROM cash_checkpoints');
    final value = rows.first['last'] as String?;
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// إجمالي الكاش المتوقع في الدرج من كل المستخدمين مجتمعين، من آخر نقطة
  /// استلام لحد دلوقتي (أو من أول فاتورة على الإطلاق لو مفيش استلام قبل كده)
  Future<double> getExpectedCashSinceLastCheckpoint() async {
    final lastCheckpoint = await getLastCheckpointTime();
    final since = lastCheckpoint?.toIso8601String() ?? '0000-01-01T00:00:00';
    final rows = await _db.database.rawQuery('''
      SELECT SUM(total_amount) as total FROM sales WHERE date >= ? AND payment_method = 'cash'
    ''', [since]);
    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// تسجيل نقطة استلام جديدة - بيحسب المتوقع تلقائيًا وقت الاستلام نفسه
  /// عشان يبقى دقيق للحظة التأكيد بالظبط
  Future<int> recordCheckpoint({required int byUserId, required double actualAmount, String? notes}) async {
    final expected = await getExpectedCashSinceLastCheckpoint();
    return _db.database.insert('cash_checkpoints', {
      'by_user_id': byUserId,
      'expected_amount': expected,
      'actual_amount': actualAmount,
      'at': DateTime.now().toIso8601String(),
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
    });
  }

  /// سجل كل نقاط الاستلام بترتيب زمني (الأحدث أولًا) مع اسم مين استلم
  Future<List<Map<String, dynamic>>> getAllCheckpoints() async {
    return _db.database.rawQuery('''
      SELECT cash_checkpoints.*, users.name as by_user_name
      FROM cash_checkpoints
      JOIN users ON users.id = cash_checkpoints.by_user_id
      ORDER BY cash_checkpoints.at DESC
    ''');
  }
}
