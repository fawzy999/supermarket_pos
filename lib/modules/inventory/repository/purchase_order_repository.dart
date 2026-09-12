import '../../../core/database/app_database.dart';

/// طلبات التوريد/الشراء الاحترافية: طلب يتبعت للمورد فيه شعار وبيانات
/// المحل، بيانات المورد كاملة، وجدول أصناف وكميات وأسعار - يتحول
/// لملف PDF ويترسل واتساب/إيميل أو يتطبع، ويتحفظ سجله في بروفايل
/// المورد.
class PurchaseOrderRepository {
  final _db = AppDatabase.instance;

  Future<int> createOrder({
    int? supplierId,
    required String supplierName,
    String? supplierPhone,
    String? supplierEmail,
    String? supplierAddress,
    String? notes,
    String? createdBy,
    required List<Map<String, dynamic>> items,
  }) async {
    final now = DateTime.now().toIso8601String();
    final total = items.fold<double>(
      0,
      (sum, item) => sum + ((item['quantity'] as num).toDouble() * (item['unit_price'] as num).toDouble()),
    );

    late int orderId;
    await _db.database.transaction((txn) async {
      orderId = await txn.insert('purchase_orders', {
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'supplier_phone': supplierPhone,
        'supplier_email': supplierEmail,
        'supplier_address': supplierAddress,
        'status': 'sent',
        'notes': notes,
        'created_by': createdBy,
        'date': now,
        'total_amount': total,
      });

      for (final item in items) {
        await txn.insert('purchase_order_items', {
          'purchase_order_id': orderId,
          'product_id': item['product_id'],
          'item_name': item['item_name'],
          'unit': item['unit'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
        });
      }
    });

    return orderId;
  }

  Future<List<Map<String, dynamic>>> getOrdersForSupplier(int supplierId) {
    return _db.database.query(
      'purchase_orders',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'date DESC',
    );
  }

  Future<Map<String, dynamic>?> getOrderById(int id) async {
    final rows = await _db.database.query('purchase_orders', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getItemsForOrder(int orderId) {
    return _db.database.query('purchase_order_items', where: 'purchase_order_id = ?', whereArgs: [orderId]);
  }

  Future<void> deleteOrder(int id) async {
    await _db.database.transaction((txn) async {
      await txn.delete('purchase_order_items', where: 'purchase_order_id = ?', whereArgs: [id]);
      await txn.delete('purchase_orders', where: 'id = ?', whereArgs: [id]);
    });
  }
}
