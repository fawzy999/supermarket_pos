import '../../../core/database/app_database.dart';

class DailyClosingRepository {
  final _db = AppDatabase.instance;

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// بيحسب أرقام يوم معين (من غير ما يسجلها) - تاريخ بصيغة yyyy-MM-dd
  Future<Map<String, dynamic>> calculateDaySummary(String dateOnly) async {
    final dayStart = '${dateOnly}T00:00:00';
    final dayEnd = '${dateOnly}T23:59:59';

    final totalResult = await _db.database.rawQuery('''
      SELECT COUNT(*) as invoice_count, SUM(total_amount) as total
      FROM sales WHERE date >= ? AND date <= ?
    ''', [dayStart, dayEnd]);

    final cashResult = await _db.database.rawQuery('''
      SELECT SUM(total_amount) as total FROM sales
      WHERE date >= ? AND date <= ? AND payment_method = 'cash'
    ''', [dayStart, dayEnd]);

    final cardResult = await _db.database.rawQuery('''
      SELECT SUM(total_amount) as total FROM sales
      WHERE date >= ? AND date <= ? AND payment_method = 'card'
    ''', [dayStart, dayEnd]);

    final profitResult = await _db.database.rawQuery('''
      SELECT SUM((sale_items.unit_price - products.purchase_price) * sale_items.quantity) as profit
      FROM sale_items
      JOIN sales ON sales.id = sale_items.sale_id
      JOIN products ON products.id = sale_items.product_id
      WHERE sales.date >= ? AND sales.date <= ?
    ''', [dayStart, dayEnd]);

    final expensesResult = await _db.database.rawQuery('''
      SELECT SUM(amount) as total FROM expenses WHERE date >= ? AND date <= ?
    ''', [dayStart, dayEnd]);

    return {
      'invoice_count': (totalResult.first['invoice_count'] as int?) ?? 0,
      'total_revenue': (totalResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'cash_total': (cashResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'card_total': (cardResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'total_profit': (profitResult.first['profit'] as num?)?.toDouble() ?? 0.0,
      'total_expenses': (expensesResult.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<bool> isClosed(String dateOnly) async {
    final rows = await _db.database.query('daily_closings', where: 'closing_date = ?', whereArgs: [dateOnly]);
    return rows.isNotEmpty;
  }

  /// بيقفل يوم معين رسميًا - بيتجاهل الطلب لو مقفول بالفعل (كل يوم بيتقفل مرة واحدة بس)
  Future<void> closeDay(String dateOnly, {int? closedBy}) async {
    if (await isClosed(dateOnly)) return;

    final summary = await calculateDaySummary(dateOnly);
    await _db.database.insert('daily_closings', {
      'closing_date': dateOnly,
      'invoice_count': summary['invoice_count'],
      'total_revenue': summary['total_revenue'],
      'total_profit': summary['total_profit'],
      'total_expenses': summary['total_expenses'],
      'cash_total': summary['cash_total'],
      'card_total': summary['card_total'],
      'closed_by': closedBy,
      'closed_at': DateTime.now().toIso8601String(),
    });
  }

  /// بيدوّر على أي أيام سابقة (قبل النهاردة) فيها مبيعات ومفيهاش إقفال، ويقفلها تلقائيًا
  /// ده بيتنادى كل ما التطبيق يفتح - بيحقق نفس فكرة "الإقفال في نص الليل" عمليًا
  Future<int> autoCloseUnclosedPastDays() async {
    final today = _dateOnly(DateTime.now());

    final distinctDates = await _db.database.rawQuery('''
      SELECT DISTINCT substr(date, 1, 10) as sale_date FROM sales
      WHERE substr(date, 1, 10) < ?
      ORDER BY sale_date
    ''', [today]);

    int closedCount = 0;
    for (final row in distinctDates) {
      final saleDate = row['sale_date'] as String;
      if (!await isClosed(saleDate)) {
        await closeDay(saleDate);
        closedCount++;
      }
    }
    return closedCount;
  }

  Future<List<Map<String, dynamic>>> getClosingHistory() async {
    return _db.database.query('daily_closings', orderBy: 'closing_date DESC');
  }

  static String todayDateOnly() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
