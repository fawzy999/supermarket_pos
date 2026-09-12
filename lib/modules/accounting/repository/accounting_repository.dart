import '../../../core/database/app_database.dart';
import '../models/expense.dart';

class AccountingRepository {
  final _db = AppDatabase.instance;

  /// إجمالي المبيعات من تاريخ معين
  Future<double> getRevenue({required String sinceDate}) async {
    final result = await _db.database.rawQuery(
      'SELECT SUM(total_amount) as total FROM sales WHERE date >= ?',
      [sinceDate],
    );
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  /// إجمالي الربح = (سعر البيع - سعر الشراء) × الكمية، لكل عناصر الفواتير من تاريخ معين
  Future<double> getProfit({required String sinceDate}) async {
    final result = await _db.database.rawQuery('''
      SELECT SUM((sale_items.unit_price - products.purchase_price) * sale_items.quantity) as profit
      FROM sale_items
      JOIN sales ON sales.id = sale_items.sale_id
      JOIN products ON products.id = sale_items.product_id
      WHERE sales.date >= ?
    ''', [sinceDate]);
    final profit = result.first['profit'];
    return profit == null ? 0.0 : (profit as num).toDouble();
  }

  /// إجمالي المبيعات في فترة محددة (من تاريخ لحد تاريخ) - لمقارنة فترة
  /// بفترة سابقة (مثلاً الأسبوع ده مقابل الأسبوع اللي فات)
  Future<double> getRevenueBetween({required String start, required String end}) async {
    final result = await _db.database.rawQuery(
      'SELECT SUM(total_amount) as total FROM sales WHERE date >= ? AND date < ?',
      [start, end],
    );
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getRevenueByCashier({required String sinceDate}) async {
    return _db.database.rawQuery('''
      SELECT users.name as cashier_name, SUM(sales.total_amount) as total
      FROM sales
      JOIN users ON users.id = sales.user_id
      WHERE sales.date >= ?
      GROUP BY sales.user_id
      ORDER BY total DESC
    ''', [sinceDate]);
  }

  Future<double> getTotalExpenses({required String sinceDate}) async {
    final result = await _db.database.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE date >= ?',
      [sinceDate],
    );
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  Future<List<Expense>> getExpenses({String? sinceDate}) async {
    final rows = await _db.database.query(
      'expenses',
      where: sinceDate != null ? 'date >= ?' : null,
      whereArgs: sinceDate != null ? [sinceDate] : null,
      orderBy: 'date DESC',
    );
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  Future<int> addExpense(Expense expense) async {
    return _db.database.insert('expenses', expense.toMap());
  }

  Future<void> deleteExpense(int id) async {
    await _db.database.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  static String startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).toIso8601String();
  }

  static String startOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1).toIso8601String();
  }

  /// بداية الأسبوع الحالي (السبت - أول أيام الأسبوع في مصر)
  static String startOfWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Dart: Monday=1 ... Sunday=7. السبت = 6، فبنرجع لأقرب سبت فات
    final daysSinceSaturday = (today.weekday - DateTime.saturday + 7) % 7;
    return today.subtract(Duration(days: daysSinceSaturday)).toIso8601String();
  }
}
