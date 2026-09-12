import '../../../core/database/app_database.dart';
import '../../customers/repository/customer_repository.dart';
import '../../inventory/repository/supply_batch_repository.dart';
import '../models/cart_item.dart';
import '../models/sale.dart';

/// اسم نوع عنصر السلة زي ما بيتخزن في عمود item_type بجدول sale_items
String _itemTypeKey(CartItemType type) => switch (type) {
      CartItemType.product => 'product',
      CartItemType.manual => 'manual',
      CartItemType.service => 'service',
    };

class SalesRepository {
  final _db = AppDatabase.instance;
  final _supplyBatchRepository = SupplyBatchRepository();
  final _customerRepository = CustomerRepository();

  /// اسم "الخدمة" اللي مبلغها بيُستبعد من مديونية المندوب في بيع "حساب
  /// مندوب" - لأن المندوب هو اللي هياخد فلوس التوصيل لنفسه، فمش بيتحسب
  /// عليه كمديونية للمحل. المطابقة بالاسم بالظبط (بعد شيل المسافات) زي
  /// ما اتفقنا - أي اسم خدمة تاني (تغليف مثلًا) يفضل جزء من مديونيته.
  static const _deliveryServiceName = 'توصيل';

  /// إجمالي بنود "توصيل" في السلة - بيُستبعد من مديونية المندوب فقط
  double _deliveryExcludedAmount(List<CartItem> cartItems) {
    return cartItems
        .where((i) => i.type == CartItemType.service && i.manualName.trim() == _deliveryServiceName)
        .fold<double>(0, (sum, item) => sum + item.lineTotal);
  }

  /// تنفيذ عملية بيع كاملة:
  /// 1. حفظ الفاتورة في جدول sales
  /// 2. حفظ كل صنف في sale_items
  /// 3. خصم الكمية من المخزون في products
  /// 4. تسجيل حركة "خروج" في inventory_movements
  /// 5. لو البيع "آجل"، زيادة رصيد العميل المرتبط بقيمة الفاتورة
  /// 6. لو البيع "حساب مندوب"، تسجيل قيمة الفاتورة (من غير خدمة التوصيل)
  /// كمديونية نقدية على المندوب - البضاعة بتتخصم من مخزون المحل على طول
  /// (زي الكاش/الفيزا) من غير أي خطوة عهدة قبلها، والمديونية دي بتفضل
  /// على المندوب لحد ما يتسجل تسوية/سداد منه (شاشة "حساب المندوب")
  /// كل ده في معاملة واحدة (Transaction) عشان لو حصل خطأ في أي خطوة،
  /// كل الخطوات ترجع لورا (مفيش فاتورة ناقصة أو مخزون اتخصم غلط)
  Future<int> checkout({
    required List<CartItem> cartItems,
    required String paymentMethod,
    int? userId,
    String? customerName,
    String? customerPhone,
    int? customerId,
    double discountPercent = 0,
    int? repId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final subtotal = cartItems.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final discountAmount = subtotal * (discountPercent / 100);
    final totalAmount = subtotal - discountAmount;

    late int saleId;

    await _db.database.transaction((txn) async {
      // 1. حفظ الفاتورة
      saleId = await txn.insert('sales', {
        'user_id': userId,
        'date': now,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'device_id': null,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_id': customerId,
        'subtotal_amount': subtotal,
        'discount_percent': discountPercent,
        'discount_amount': discountAmount,
        'rep_id': paymentMethod == 'rep_account' ? repId : null,
      });

      // 5. بيع آجل لازم يكون مرتبط بعميل مسجّل، وقيمته (بعد الخصم)
      // بتتضاف لرصيده (بيتحصّل لاحقًا من شاشة بروفايل العميل)
      if (paymentMethod == 'credit' && customerId != null) {
        await _customerRepository.increaseBalance(
          txn: txn,
          customerId: customerId,
          amount: totalAmount,
        );
      }

      // 6. حساب مندوب: مديونية نقدية على المندوب بقيمة الفاتورة ناقص
      // خدمة التوصيل (المندوب هياخد فلوسها لنفسه) - بنفس آلية "المبيعات
      // الكاش" لحساب المندوب (rep_sales بـ payment_method='cash')، عشان
      // تظهر تلقائيًا في شاشة "حساب المندوب" وتتقفل مع أي تسوية بعد كده
      if (paymentMethod == 'rep_account' && repId != null) {
        final deliveryExcluded = _deliveryExcludedAmount(cartItems);
        final repOwedAmount = totalAmount - deliveryExcluded;
        await txn.insert('rep_sales', {
          'rep_id': repId,
          'customer_id': customerId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'payment_method': 'cash',
          'total_amount': repOwedAmount,
          'notes': 'فاتورة كاشير رقم #$saleId'
              '${deliveryExcluded > 0 ? ' (خصم توصيل ${deliveryExcluded.toStringAsFixed(2)} ج للمندوب)' : ''}',
          'date': now,
        });
      }

      for (final item in cartItems) {
        // 2. حفظ عنصر الفاتورة (صنف حقيقي من المخزون، أو صنف يدوي/خدمة)
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.type == CartItemType.product ? item.product!.id : null,
          'item_type': _itemTypeKey(item.type),
          'manual_name': item.type == CartItemType.product ? null : item.manualName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
        });

        // الصنف اليدوي أو الخدمة مالوش مخزون فعلي - نوقف هنا وننتقل للتالي
        if (item.type != CartItemType.product) continue;

        // 3. خصم الكمية من المخزون
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [item.quantity, item.product!.id],
        );

        // 3.5 خصم نفس الكمية من دفعات التوريد بنظام FIFO، عشان "الكمية
        // المتبقية" في شاشة توريدات الصنف تتحدث فعليًا مع كل عملية بيع
        // (قبل كده الخصم كان بيحصل على إجمالي الصنف بس من غير ما يلمس الدفعات)
        await _supplyBatchRepository.deductFifo(
          txn: txn,
          productId: item.product!.id!,
          quantity: item.quantity,
        );

        // 4. تسجيل حركة الخروج
        await txn.insert('inventory_movements', {
          'product_id': item.product!.id,
          'type': 'out',
          'quantity': item.quantity,
          'reference_id': saleId,
          'date': now,
        });
      }
    });

    return saleId;
  }

  Future<List<Sale>> getSalesHistory({String? sinceDate}) async {
    final rows = await _db.database.query(
      'sales',
      where: sinceDate != null ? 'date >= ?' : null,
      whereArgs: sinceDate != null ? [sinceDate] : null,
      orderBy: 'date DESC',
    );
    return rows.map((r) => Sale.fromMap(r)).toList();
  }

  Future<double> getTodayTotal() async {
    final todayStart = DateTime.now().toIso8601String().split('T').first;
    final result = await _db.database.rawQuery(
      'SELECT SUM(total_amount) as total FROM sales WHERE date >= ?',
      ['${todayStart}T00:00:00'],
    );
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  Future<Sale?> getSaleById(int saleId) async {
    final rows = await _db.database.query('sales', where: 'id = ?', whereArgs: [saleId]);
    if (rows.isEmpty) return null;
    return Sale.fromMap(rows.first);
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    return _db.database.rawQuery('''
      SELECT sale_items.*, COALESCE(products.name, sale_items.manual_name) as product_name
      FROM sale_items
      LEFT JOIN products ON products.id = sale_items.product_id
      WHERE sale_items.sale_id = ?
    ''', [saleId]);
  }
}
