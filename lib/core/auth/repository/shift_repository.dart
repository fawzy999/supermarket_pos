import '../../database/app_database.dart';
import '../models/shift.dart';

class ShiftRepository {
  final _db = AppDatabase.instance;

  /// بيبدأ وردية جديدة وقت تسجيل الدخول، ويرجع رقمها
  Future<int> startShift(int userId) async {
    return _db.database.insert('shifts', {
      'user_id': userId,
      'login_time': DateTime.now().toIso8601String(),
      'logout_time': null,
    });
  }

  /// أي وردية لسه مفتوحة دلوقتي (المفروض توجد وردية مفتوحة واحدة بس، لأن
  /// الجهاز واحد ودرج واحد) - بتُستخدم عند الدخول عشان نعرف نكمّل نفس
  /// الوردية ولا نطلب تسليم عهدة من مستخدم مختلف
  Future<Shift?> getOpenShift() async {
    final rows = await _db.database.query(
      'shifts',
      where: 'logout_time IS NULL',
      orderBy: 'login_time DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Shift.fromMap(rows.first);
  }

  /// بيقفل الوردية وقت تسجيل الخروج، وبيحفظ ملخصها المالي بشكل دائم
  /// (مش بس بيعرضه لحظيًا) عشان يبقى قابل للمراجعة بعدين وقت تسليم العهدة
  Future<void> endShift(
    int shiftId, {
    required int invoiceCount,
    required double cashTotal,
    required double cardTotal,
    required double totalAmount,
  }) async {
    await _db.database.update(
      'shifts',
      {
        'logout_time': DateTime.now().toIso8601String(),
        'invoice_count': invoiceCount,
        'cash_total': cashTotal,
        'card_total': cardTotal,
        'total_amount': totalAmount,
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  /// تأكيد استلام العهدة من الشخص التالي (كاشير جديد أو أدمن) - مراجعة يدوية
  /// لاحقة من شاشة تفاصيل الوردية (بالإضافة لمسار الاستلام الإجباري وقت الدخول)
  Future<void> confirmReceipt(int shiftId, int confirmedByUserId) async {
    await _db.database.update(
      'shifts',
      {
        'confirmed_by': confirmedByUserId,
        'confirmed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  /// تسليم/استلام العهدة الإجباري: بيقفل وردية المستخدم القديم (بمبلغ فعلي
  /// أكّده المستلم) وبيفتح وردية جديدة للمستخدم الجديد فورًا - عملية واحدة
  /// مترابطة تحصل وقت الدخول لو لقى وردية سابقة لمستخدم مختلف لسه مفتوحة
  Future<int> handoverAndStartNewShift({
    required Shift openShift,
    required int newUserId,
    required double receivedAmount,
  }) async {
    final summary = await getShiftSummary(openShift.userId, openShift.loginTime, null);
    await _db.database.update(
      'shifts',
      {
        'logout_time': DateTime.now().toIso8601String(),
        'invoice_count': summary['invoice_count'] as int,
        'cash_total': summary['cash_total'] as double,
        'card_total': summary['card_total'] as double,
        'total_amount': summary['total'] as double,
        'confirmed_by': newUserId,
        'confirmed_at': DateTime.now().toIso8601String(),
        'received_amount': receivedAmount,
      },
      where: 'id = ?',
      whereArgs: [openShift.id],
    );
    return startShift(newUserId);
  }

  Future<Shift?> getShift(int shiftId) async {
    final rows = await _db.database.query('shifts', where: 'id = ?', whereArgs: [shiftId]);
    if (rows.isEmpty) return null;
    return Shift.fromMap(rows.first);
  }

  /// سجل كل الورديات (للأدمن) - بأحدث وردية أولًا، مع اسم صاحبها ومين أكّد الاستلام
  Future<List<Map<String, dynamic>>> getAllShifts() async {
    return _db.database.rawQuery('''
      SELECT shifts.*, users.name as user_name, confirmer.name as confirmed_by_name
      FROM shifts
      JOIN users ON users.id = shifts.user_id
      LEFT JOIN users as confirmer ON confirmer.id = shifts.confirmed_by
      ORDER BY shifts.login_time DESC
    ''');
  }

  /// كل الفواتير اللي اتباعت خلال وردية معينة (تفاصيل الأصناف مع كل فاتورة)
  Future<List<Map<String, dynamic>>> getInvoicesForShift(int userId, String loginTime, String? logoutTime) async {
    final endTime = logoutTime ?? DateTime.now().toIso8601String();
    return _db.database.rawQuery('''
      SELECT id, date, total_amount, payment_method
      FROM sales
      WHERE user_id = ? AND date >= ? AND date <= ?
      ORDER BY date DESC
    ''', [userId, loginTime, endTime]);
  }

  /// ملخص المبيعات خلال وردية معينة - عشان تسليم العهدة
  Future<Map<String, dynamic>> getShiftSummary(int userId, String loginTime, String? logoutTime) async {
    final endTime = logoutTime ?? DateTime.now().toIso8601String();

    final totalResult = await _db.database.rawQuery('''
      SELECT COUNT(*) as invoice_count, SUM(total_amount) as total
      FROM sales
      WHERE user_id = ? AND date >= ? AND date <= ?
    ''', [userId, loginTime, endTime]);

    final cashResult = await _db.database.rawQuery('''
      SELECT SUM(total_amount) as total
      FROM sales
      WHERE user_id = ? AND date >= ? AND date <= ? AND payment_method = 'cash'
    ''', [userId, loginTime, endTime]);

    final cardResult = await _db.database.rawQuery('''
      SELECT SUM(total_amount) as total
      FROM sales
      WHERE user_id = ? AND date >= ? AND date <= ? AND payment_method = 'card'
    ''', [userId, loginTime, endTime]);

    return {
      'invoice_count': (totalResult.first['invoice_count'] as int?) ?? 0,
      'total': (totalResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'cash_total': (cashResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'card_total': (cardResult.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// بيسجل حدث فتح/قفل التطبيق (معلوماتي بس، من غير أي تأثير على الوردية)
  Future<void> logAppEvent({required String event, int? shiftId, int? userId}) async {
    await _db.database.insert('app_open_close_log', {
      'shift_id': shiftId,
      'user_id': userId,
      'event': event,
      'at': DateTime.now().toIso8601String(),
    });
  }

  /// سجل فتح/قفل التطبيق خلال وردية معينة
  Future<List<Map<String, dynamic>>> getAppEventsForShift(int shiftId) async {
    return _db.database.rawQuery('''
      SELECT * FROM app_open_close_log WHERE shift_id = ? ORDER BY at ASC
    ''', [shiftId]);
  }

  /// آخر وقت اتقفلت فيه وردية بتسليم عهدة مؤكَّد (مش بس logout_time عادي) -
  /// يُستخدم في حساب دورة الإقفال الإجباري كل 24 ساعة
  Future<DateTime?> getLastConfirmedClosureTime() async {
    final rows = await _db.database.rawQuery('''
      SELECT MAX(confirmed_at) as last FROM shifts WHERE confirmed_at IS NOT NULL
    ''');
    final value = rows.first['last'] as String?;
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// أقدم وردية مسجّلة على الإطلاق - تُستخدم كنقطة بداية للعداد لو لسه مفيش
  /// أي إقفال/استلام حصل خالص من أول ما التطبيق اتثبّت
  Future<DateTime?> getEarliestShiftTime() async {
    final rows = await _db.database.rawQuery('''
      SELECT MIN(login_time) as first FROM shifts
    ''');
    final value = rows.first['first'] as String?;
    if (value == null) return null;
    return DateTime.tryParse(value);
  }
}
