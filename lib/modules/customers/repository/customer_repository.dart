import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../models/customer.dart';

class CustomerRepository {
  final _db = AppDatabase.instance;

  Future<List<Customer>> getAllCustomers({String? searchQuery}) async {
    List<Map<String, dynamic>> rows;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      rows = await _db.database.query(
        'customers',
        where: 'name LIKE ? OR phone LIKE ?',
        whereArgs: ['%$searchQuery%', '%$searchQuery%'],
        orderBy: 'name',
      );
    } else {
      rows = await _db.database.query('customers', orderBy: 'name');
    }
    return rows.map((r) => Customer.fromMap(r)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final rows = await _db.database.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<int> addCustomer(Customer customer) {
    return _db.database.insert('customers', customer.toMap());
  }

  Future<void> updateCustomer(Customer customer) {
    return _db.database.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  /// كل الفواتير (الآجلة وغيرها) المرتبطة بعميل مسجّل
  Future<List<Map<String, dynamic>>> getSalesForCustomer(int customerId) async {
    return _db.database.query(
      'sales',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPaymentsForCustomer(int customerId) async {
    return _db.database.query(
      'customer_payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
  }

  /// بيزوّد رصيد العميل (بيع آجل جديد) - بتتنفذ جوه معاملة عملية البيع
  Future<void> increaseBalance({
    required DatabaseExecutor txn,
    required int customerId,
    required double amount,
  }) async {
    await txn.rawUpdate(
      'UPDATE customers SET balance = balance + ? WHERE id = ?',
      [amount, customerId],
    );
  }

  /// تسجيل تحصيل (دفعة من العميل) - بيقلل رصيده وبيسجل الدفعة في السجل
  Future<void> recordPayment({
    required int customerId,
    required double amount,
    String? notes,
    String? receivedBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.database.transaction((txn) async {
      await txn.insert('customer_payments', {
        'customer_id': customerId,
        'amount': amount,
        'date': now,
        'notes': notes,
        'received_by': receivedBy,
      });
      await txn.rawUpdate(
        'UPDATE customers SET balance = balance - ? WHERE id = ?',
        [amount, customerId],
      );
    });
  }

  Future<double> getTotalOutstandingBalance() async {
    final result = await _db.database.rawQuery(
      'SELECT SUM(balance) as total FROM customers WHERE balance > 0',
    );
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  // ---------------- نقاط الولاء ----------------

  /// إضافة نقاط (كسب) أو خصمها (استبدال - بعدد سالب) لعميل، مع تسجيل الحركة
  Future<void> addLoyaltyPoints({
    required int customerId,
    required int points,
    String? reason,
  }) async {
    await _db.database.transaction((txn) async {
      await txn.insert('customer_loyalty_transactions', {
        'customer_id': customerId,
        'points': points,
        'reason': reason,
        'date': DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate(
        'UPDATE customers SET loyalty_points = loyalty_points + ? WHERE id = ?',
        [points, customerId],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getLoyaltyTransactions(int customerId) async {
    return _db.database.query(
      'customer_loyalty_transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
  }
}
