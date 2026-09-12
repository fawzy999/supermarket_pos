import '../../../core/database/app_database.dart';

class ReturnsRepository {
  final _db = AppDatabase.instance;

  /// مرتجع عميل: بيرجّع كمية من صنف اتباعت قبل كده في فاتورة، وبيزّودها
  /// تاني في المخزون كدفعة توريد جديدة (عشان تفضل جزء من نظام الـ FIFO)،
  /// ولو الفاتورة الأصلية كانت آجل ومرتبطة بعميل، بيقلل من رصيده بقد قيمة
  /// المرتجع.
  Future<int> recordCustomerReturn({
    required int productId,
    required double quantity,
    required double unitPrice,
    int? referenceSaleId,
    String? reason,
    String? processedBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    late int returnId;

    await _db.database.transaction((txn) async {
      returnId = await txn.insert('returns', {
        'type': 'customer',
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'reference_sale_id': referenceSaleId,
        'reason': reason,
        'date': now,
        'processed_by': processedBy,
      });

      // إضافة الكمية تاني للمخزون
      await txn.rawUpdate(
        'UPDATE products SET quantity = quantity + ? WHERE id = ?',
        [quantity, productId],
      );

      // تسجيلها كدفعة توريد جديدة (بدون تاريخ صلاحية معروف) عشان تفضل
      // متتبّعة في نظام الدفعات ومتاحة للبيع تاني بنفس منطق الـ FIFO
      await txn.insert('supply_batches', {
        'product_id': productId,
        'supplier_id': null,
        'quantity_received': quantity,
        'remaining_quantity': quantity,
        'supply_date': now,
        'expiry_date': null,
        'received_by': processedBy,
        'notes': referenceSaleId != null
            ? 'مرتجع من فاتورة رقم #$referenceSaleId'
            : 'مرتجع عميل',
      });

      await txn.insert('inventory_movements', {
        'product_id': productId,
        'type': 'return_in',
        'quantity': quantity,
        'reference_id': returnId,
        'date': now,
      });

      // لو الفاتورة الأصلية كانت آجل ومرتبطة بعميل، نقلل من رصيده بقد
      // قيمة المرتجع (مش المفروض يفضل مديون بقيمة بضاعة رجعها فعلًا)
      if (referenceSaleId != null) {
        final saleRows = await txn.query(
          'sales',
          where: 'id = ?',
          whereArgs: [referenceSaleId],
        );
        if (saleRows.isNotEmpty) {
          final sale = saleRows.first;
          final customerId = sale['customer_id'] as int?;
          if (sale['payment_method'] == 'credit' && customerId != null) {
            await txn.rawUpdate(
              'UPDATE customers SET balance = balance - ? WHERE id = ?',
              [quantity * unitPrice, customerId],
            );
          }
        }
      }
    });

    return returnId;
  }

  /// مرتجع مورد: بيخصم كمية من دفعة توريد محددة (بضاعة تالفة/منتهية بترجع
  /// للمورد)، وبيقلل بيها إجمالي كمية الصنف كمان.
  Future<int> recordSupplierReturn({
    required int productId,
    required int batchId,
    int? supplierId,
    required double quantity,
    String? reason,
    String? processedBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    late int returnId;

    await _db.database.transaction((txn) async {
      returnId = await txn.insert('returns', {
        'type': 'supplier',
        'product_id': productId,
        'quantity': quantity,
        'supplier_id': supplierId,
        'batch_id': batchId,
        'reason': reason,
        'date': now,
        'processed_by': processedBy,
      });

      await txn.rawUpdate(
        'UPDATE supply_batches SET remaining_quantity = remaining_quantity - ? WHERE id = ?',
        [quantity, batchId],
      );

      await txn.rawUpdate(
        'UPDATE products SET quantity = quantity - ? WHERE id = ?',
        [quantity, productId],
      );

      await txn.insert('inventory_movements', {
        'product_id': productId,
        'type': 'return_out',
        'quantity': quantity,
        'reference_id': returnId,
        'date': now,
      });
    });

    return returnId;
  }

  Future<List<Map<String, dynamic>>> getReturnsHistory({int limit = 300}) async {
    return _db.database.rawQuery('''
      SELECT returns.*, products.name as product_name, suppliers.company_name as supplier_name
      FROM returns
      JOIN products ON products.id = returns.product_id
      LEFT JOIN suppliers ON suppliers.id = returns.supplier_id
      ORDER BY returns.date DESC, returns.id DESC
      LIMIT ?
    ''', [limit]);
  }
}
