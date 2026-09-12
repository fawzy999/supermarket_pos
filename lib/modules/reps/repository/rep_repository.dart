import '../../../core/database/app_database.dart';
import '../../inventory/repository/supply_batch_repository.dart';
import '../models/rep.dart';

/// المسؤول عن كل عمليات موديول "المناديب والشحن":
/// بروفايل المندوب، عهدة البضاعة اللي معاه، فواتير بيعه الخارجي،
/// طلبات التوصيل اللي بيتابعها، التحصيل من العملاء، والتسوية الدورية.
///
/// المنطق الأساسي: المندوب زي "شركة شحن صغيرة" جوه المحل - بياخد بضاعة
/// على عهدته من المخزون الرئيسي (سحب)، يبيعها لعملاء خارج المحل أو
/// يوصّلها لطلبات اتسجلت من المحل، وفي الآخر بيترجع أو يتحاسب على الفرق.
class RepRepository {
  final _db = AppDatabase.instance;
  final _supplyBatchRepository = SupplyBatchRepository();

  // ---------------- بروفايل المندوب ----------------

  Future<List<Rep>> getAllReps({String? searchQuery, bool activeOnly = false}) async {
    final conditions = <String>[];
    final args = <Object>[];
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(name LIKE ? OR phone LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }
    if (activeOnly) conditions.add('active = 1');

    final rows = await _db.database.query(
      'reps',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: conditions.isEmpty ? null : args,
      orderBy: 'name',
    );
    return rows.map((r) => Rep.fromMap(r)).toList();
  }

  Future<Rep?> getRepById(int id) async {
    final rows = await _db.database.query('reps', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Rep.fromMap(rows.first);
  }

  Future<int> addRep(Rep rep) => _db.database.insert('reps', rep.toMap());

  Future<void> updateRep(Rep rep) => _db.database.update(
        'reps',
        rep.toMap(),
        where: 'id = ?',
        whereArgs: [rep.id],
      );

  Future<void> setActive(int repId, bool active) => _db.database.update(
        'reps',
        {'active': active ? 1 : 0},
        where: 'id = ?',
        whereArgs: [repId],
      );

  // ---------------- عهدة البضاعة ----------------

  /// سحب كمية من المخزون الرئيسي لعهدة المندوب: حركة خروج خاصة (مش بيع)،
  /// بتخصم من المخزون العام (وبنظام FIFO من دفعات التوريد) وتضيفها لعهدته.
  Future<void> withdrawToCustody({
    required int repId,
    required int productId,
    required double quantity,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.database.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE products SET quantity = quantity - ? WHERE id = ?',
        [quantity, productId],
      );
      await _supplyBatchRepository.deductFifo(txn: txn, productId: productId, quantity: quantity);
      await txn.insert('inventory_movements', {
        'product_id': productId,
        'type': 'out',
        'quantity': quantity,
        'reference_id': repId,
        'date': now,
      });
      await txn.insert('rep_custody', {
        'rep_id': repId,
        'product_id': productId,
        'type': 'withdraw',
        'quantity': quantity,
        'notes': notes,
        'date': now,
      });
    });
  }

  /// إرجاع فائض من عهدة المندوب للمخزون الرئيسي: بيزوّد المخزون العام
  /// تاني (كدفعة توريد جديدة بلا تاريخ صلاحية، عشان تفضل قابلة للبيع
  /// بنفس نظام الـ FIFO) وينقص من عهدة المندوب.
  Future<void> returnFromCustody({
    required int repId,
    required int productId,
    required double quantity,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.database.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE products SET quantity = quantity + ? WHERE id = ?',
        [quantity, productId],
      );
      await txn.insert('supply_batches', {
        'product_id': productId,
        'supplier_id': null,
        'quantity_received': quantity,
        'remaining_quantity': quantity,
        'supply_date': now,
        'expiry_date': null,
        'received_by': null,
        'notes': 'مرتجع عهدة مندوب',
      });
      await txn.insert('inventory_movements', {
        'product_id': productId,
        'type': 'in',
        'quantity': quantity,
        'reference_id': repId,
        'date': now,
      });
      await txn.insert('rep_custody', {
        'rep_id': repId,
        'product_id': productId,
        'type': 'return',
        'quantity': quantity,
        'notes': notes,
        'date': now,
      });
    });
  }

  /// تسجيل فرق جرد (نقص/زيادة) في عهدة المندوب وقت التسوية الدورية،
  /// من غير ما يلمس مخزون المحل الرئيسي (البضاعة أصلًا خارجة منه).
  Future<void> recordCustodyAdjustment({
    required int repId,
    required int productId,
    required double quantity, // موجب = زيادة في العهدة، سالب = نقص/فاقد
    String? notes,
  }) async {
    await _db.database.insert('rep_custody', {
      'rep_id': repId,
      'product_id': productId,
      'type': 'adjustment',
      'quantity': quantity,
      'notes': notes,
      'date': DateTime.now().toIso8601String(),
    });
  }

  /// سجل حركة العهدة الكامل لمندوب معين (سحب/إرجاع/بيع/تسوية) بالتاريخ والوقت
  Future<List<Map<String, dynamic>>> getCustodyLedger(int repId) async {
    return _db.database.rawQuery('''
      SELECT rep_custody.*, products.name as product_name
      FROM rep_custody
      JOIN products ON products.id = rep_custody.product_id
      WHERE rep_custody.rep_id = ?
      ORDER BY rep_custody.date DESC, rep_custody.id DESC
    ''', [repId]);
  }

  /// الرصيد الحالي (الكمية المتبقية فعليًا) لكل صنف في عهدة مندوب معين:
  /// سحب - إرجاع - مبيعات + تسويات
  Future<List<Map<String, dynamic>>> getCustodyBalance(int repId) async {
    return _db.database.rawQuery('''
      SELECT
        rep_custody.product_id,
        products.name as product_name,
        SUM(
          CASE rep_custody.type
            WHEN 'withdraw' THEN rep_custody.quantity
            WHEN 'return' THEN -rep_custody.quantity
            WHEN 'sale' THEN -rep_custody.quantity
            WHEN 'adjustment' THEN rep_custody.quantity
            ELSE 0
          END
        ) as remaining
      FROM rep_custody
      JOIN products ON products.id = rep_custody.product_id
      WHERE rep_custody.rep_id = ?
      GROUP BY rep_custody.product_id
      HAVING remaining != 0
      ORDER BY products.name
    ''', [repId]);
  }

  // ---------------- البيع الخارجي ----------------

  /// تسجيل فاتورة بيع خارجي من عهدة المندوب لعميل (كاش أو آجل).
  /// بتخصم من عهدة المندوب مباشرة - مش من مخزون المحل (خارج بالفعل).
  Future<int> recordExternalSale({
    required int repId,
    int? customerId,
    String? customerName,
    String? customerPhone,
    required String paymentMethod, // cash / credit
    required List<Map<String, dynamic>> items, // {product_id, quantity, unit_price}
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final totalAmount = items.fold<double>(
      0,
      (sum, item) => sum + (item['quantity'] as num) * (item['unit_price'] as num),
    );

    late int repSaleId;
    await _db.database.transaction((txn) async {
      repSaleId = await txn.insert('rep_sales', {
        'rep_id': repId,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'payment_method': paymentMethod,
        'total_amount': totalAmount,
        'notes': notes,
        'date': now,
      });

      if (paymentMethod == 'credit' && customerId != null) {
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance + ? WHERE id = ?',
          [totalAmount, customerId],
        );
      }

      for (final item in items) {
        await txn.insert('rep_sale_items', {
          'rep_sale_id': repSaleId,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
        });
        await txn.insert('rep_custody', {
          'rep_id': repId,
          'product_id': item['product_id'],
          'type': 'sale',
          'quantity': item['quantity'],
          'reference_id': repSaleId,
          'notes': 'بيع خارجي #$repSaleId',
          'date': now,
        });
      }
    });

    return repSaleId;
  }

  Future<List<Map<String, dynamic>>> getExternalSalesForRep(int repId) async {
    return _db.database.query(
      'rep_sales',
      where: 'rep_id = ?',
      whereArgs: [repId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getExternalSaleItems(int repSaleId) async {
    return _db.database.rawQuery('''
      SELECT rep_sale_items.*, products.name as product_name
      FROM rep_sale_items
      JOIN products ON products.id = rep_sale_items.product_id
      WHERE rep_sale_items.rep_sale_id = ?
    ''', [repSaleId]);
  }

  // ---------------- طلبات التوصيل ----------------

  Future<int> createDelivery({
    required int repId,
    int? saleId,
    String? customerName,
    String? customerPhone,
    String? address,
    String? notes,
  }) {
    return _db.database.insert('rep_deliveries', {
      'rep_id': repId,
      'sale_id': saleId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'address': address,
      'status': 'pending',
      'notes': notes,
      'assigned_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateDeliveryStatus({
    required int deliveryId,
    required String status, // pending / delivered / returned / postponed
    String? notes,
  }) async {
    await _db.database.update(
      'rep_deliveries',
      {
        'status': status,
        if (notes != null) 'notes': notes,
        if (status == 'delivered') 'delivered_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [deliveryId],
    );
  }

  Future<List<Map<String, dynamic>>> getDeliveriesForRep(int repId) async {
    return _db.database.query(
      'rep_deliveries',
      where: 'rep_id = ?',
      whereArgs: [repId],
      orderBy: 'assigned_at DESC',
    );
  }

  /// آخر فواتير البيع من المحل (نقطة البيع) - عشان الأدمن يقدر يختار
  /// فاتورة موجودة ويكلّف مندوب بتوصيلها
  Future<List<Map<String, dynamic>>> getRecentStoreSales({int limit = 50}) async {
    return _db.database.query('sales', orderBy: 'date DESC', limit: limit);
  }

  // ---------------- التحصيل من العملاء ----------------

  /// تحصيل دفعة من عميل عن طريق المندوب - بتقلل رصيد العميل في CRM
  /// وتتسجل في سجل تحصيلات المندوب في نفس الوقت (عملية واحدة متماسكة)
  Future<void> recordCollection({
    required int repId,
    required int customerId,
    required double amount,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.database.transaction((txn) async {
      await txn.insert('rep_collections', {
        'rep_id': repId,
        'customer_id': customerId,
        'amount': amount,
        'notes': notes,
        'date': now,
      });
      await txn.insert('customer_payments', {
        'customer_id': customerId,
        'amount': amount,
        'date': now,
        'notes': notes,
        'received_by': null,
      });
      await txn.rawUpdate(
        'UPDATE customers SET balance = balance - ? WHERE id = ?',
        [amount, customerId],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getCollectionsForRep(int repId) async {
    return _db.database.rawQuery('''
      SELECT rep_collections.*, customers.name as customer_name
      FROM rep_collections
      JOIN customers ON customers.id = rep_collections.customer_id
      WHERE rep_collections.rep_id = ?
      ORDER BY rep_collections.date DESC
    ''', [repId]);
  }

  // ---------------- التسوية الدورية ----------------

  Future<int> recordSettlement({
    required int repId,
    double amount = 0,
    String? notes,
    String? settledBy,
  }) {
    return _db.database.insert('rep_settlements', {
      'rep_id': repId,
      'amount': amount,
      'notes': notes,
      'settled_by': settledBy,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSettlementsForRep(int repId) async {
    return _db.database.query(
      'rep_settlements',
      where: 'rep_id = ?',
      whereArgs: [repId],
      orderBy: 'date DESC',
    );
  }

  // ---------------- تقارير أداء ----------------

  /// ملخص أداء مندوب واحد: إجمالي مبيعاته، إجمالي تحصيله، عدد طلبات
  /// التوصيل المكتملة والمعلّقة
  Future<Map<String, dynamic>> getRepPerformanceSummary(int repId) async {
    final salesResult = await _db.database.rawQuery(
      'SELECT COUNT(*) as count, SUM(total_amount) as total FROM rep_sales WHERE rep_id = ?',
      [repId],
    );
    final collectionsResult = await _db.database.rawQuery(
      'SELECT SUM(amount) as total FROM rep_collections WHERE rep_id = ?',
      [repId],
    );
    final deliveredResult = await _db.database.rawQuery(
      "SELECT COUNT(*) as count FROM rep_deliveries WHERE rep_id = ? AND status = 'delivered'",
      [repId],
    );
    final pendingResult = await _db.database.rawQuery(
      "SELECT COUNT(*) as count FROM rep_deliveries WHERE rep_id = ? AND status = 'pending'",
      [repId],
    );
    final creditOutstandingResult = await _db.database.rawQuery(
      "SELECT SUM(total_amount) as total FROM rep_sales WHERE rep_id = ? AND payment_method = 'credit'",
      [repId],
    );

    double asDouble(Object? v) => v == null ? 0.0 : (v as num).toDouble();
    int asInt(Object? v) => v == null ? 0 : (v as num).toInt();

    return {
      'sales_count': asInt(salesResult.first['count']),
      'sales_total': asDouble(salesResult.first['total']),
      'collections_total': asDouble(collectionsResult.first['total']),
      'delivered_count': asInt(deliveredResult.first['count']),
      'pending_deliveries_count': asInt(pendingResult.first['count']),
      'credit_sales_total': asDouble(creditOutstandingResult.first['total']),
    };
  }

  /// ملخص أداء كل المناديب مع بعض - لشاشة التقارير العامة
  Future<List<Map<String, dynamic>>> getAllRepsPerformance() async {
    return _db.database.rawQuery('''
      SELECT
        reps.id as rep_id,
        reps.name as rep_name,
        reps.active as active,
        COALESCE((SELECT SUM(total_amount) FROM rep_sales WHERE rep_sales.rep_id = reps.id), 0) as sales_total,
        COALESCE((SELECT COUNT(*) FROM rep_sales WHERE rep_sales.rep_id = reps.id), 0) as sales_count,
        COALESCE((SELECT SUM(amount) FROM rep_collections WHERE rep_collections.rep_id = reps.id), 0) as collections_total,
        COALESCE((SELECT COUNT(*) FROM rep_deliveries WHERE rep_deliveries.rep_id = reps.id AND status = 'pending'), 0) as pending_deliveries
      FROM reps
      ORDER BY reps.name
    ''');
  }

  // ---------------- مستندات المندوب (بطاقة/عنوان/شهادة/عقد/إضافي - عدد غير محدود) ----------------

  Future<List<Map<String, dynamic>>> getDocumentsForRep(int repId) async {
    return _db.database.query(
      'rep_documents',
      where: 'rep_id = ?',
      whereArgs: [repId],
      orderBy: 'uploaded_at DESC',
    );
  }

  Future<int> addDocument({
    required int repId,
    required String docType,
    String? title,
    required String filePath,
    String? expiryDate,
  }) {
    return _db.database.insert('rep_documents', {
      'rep_id': repId,
      'doc_type': docType,
      'title': title,
      'file_path': filePath,
      'uploaded_at': DateTime.now().toIso8601String(),
      'expiry_date': expiryDate,
    });
  }

  Future<void> deleteDocument(int id) =>
      _db.database.delete('rep_documents', where: 'id = ?', whereArgs: [id]);

  /// مستندات منتهية أو قربت تنتهي خلال كذا يوم - لشاشة "التذكيرات"
  Future<List<Map<String, dynamic>>> getExpiringDocuments({int withinDays = 30}) async {
    final cutoff = DateTime.now().add(Duration(days: withinDays)).toIso8601String();
    return _db.database.rawQuery('''
      SELECT rep_documents.*, reps.name as rep_name, reps.phone as rep_phone
      FROM rep_documents
      JOIN reps ON reps.id = rep_documents.rep_id
      WHERE rep_documents.expiry_date IS NOT NULL AND rep_documents.expiry_date <= ?
      ORDER BY rep_documents.expiry_date ASC
    ''', [cutoff]);
  }

  /// المناديب النشطين اللي ناقصهم مستند أساسي (بطاقة رقم قومي) - لشاشة "التذكيرات"
  Future<List<Rep>> getRepsMissingCoreDocuments() async {
    final rows = await _db.database.rawQuery('''
      SELECT reps.* FROM reps
      WHERE reps.active = 1
        AND NOT EXISTS (
          SELECT 1 FROM rep_documents
          WHERE rep_documents.rep_id = reps.id AND rep_documents.doc_type = 'national_id'
        )
      ORDER BY reps.name
    ''');
    return rows.map((r) => Rep.fromMap(r)).toList();
  }

  // ---------------- ربط المندوب بالحسابات: بضاعة تحت العهدة + مديونية نقدية ----------------

  /// قيمة البضاعة تحت عهدة المندوب دلوقتي، محسوبة بسعر الشراء
  Future<double> _getCustodyValue(int repId) async {
    final result = await _db.database.rawQuery('''
      SELECT COALESCE(SUM(remaining * purchase_price), 0) as value FROM (
        SELECT
          products.purchase_price as purchase_price,
          SUM(
            CASE rep_custody.type
              WHEN 'withdraw' THEN rep_custody.quantity
              WHEN 'return' THEN -rep_custody.quantity
              WHEN 'sale' THEN -rep_custody.quantity
              WHEN 'adjustment' THEN rep_custody.quantity
              ELSE 0
            END
          ) as remaining
        FROM rep_custody
        JOIN products ON products.id = rep_custody.product_id
        WHERE rep_custody.rep_id = ?
        GROUP BY rep_custody.product_id
      )
    ''', [repId]);
    final value = result.first['value'];
    return value == null ? 0.0 : (value as num).toDouble();
  }

  /// المديونية النقدية: فلوس استلمها المندوب (مبيعات كاش + تحصيلات من
  /// عملاء) ولسه ما سلمهاش للمحل (بعد خصم التسويات النقدية اللي سلّمها)
  Future<double> _getCashOwed(int repId) async {
    final cashSales = await _db.database.rawQuery(
      "SELECT COALESCE(SUM(total_amount), 0) as total FROM rep_sales WHERE rep_id = ? AND payment_method = 'cash'",
      [repId],
    );
    final collections = await _db.database.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM rep_collections WHERE rep_id = ?',
      [repId],
    );
    final settled = await _db.database.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM rep_settlements WHERE rep_id = ?',
      [repId],
    );
    double asDouble(Object? v) => v == null ? 0.0 : (v as num).toDouble();
    return asDouble(cashSales.first['total']) +
        asDouble(collections.first['total']) -
        asDouble(settled.first['total']);
  }

  /// ملخص حساب المندوب: بضاعة تحت العهدة + مديونية نقدية = إجمالي المستحق منه
  Future<Map<String, dynamic>> getRepAccountSummary(int repId) async {
    final custodyValue = await _getCustodyValue(repId);
    final cashOwed = await _getCashOwed(repId);
    return {
      'custody_value': custodyValue,
      'cash_owed': cashOwed,
      'total_due': custodyValue + cashOwed,
    };
  }

  /// ملخص حساب كل المناديب مع بعض - لقسم "الأرصدة" في الحسابات الرئيسية
  Future<List<Map<String, dynamic>>> getAllRepsAccountSummaries() async {
    final reps = await getAllReps();
    final rows = <Map<String, dynamic>>[];
    for (final rep in reps) {
      final summary = await getRepAccountSummary(rep.id!);
      if ((summary['total_due'] as double) == 0) continue;
      rows.add({'rep_id': rep.id, 'rep_name': rep.name, ...summary});
    }
    rows.sort((a, b) => (b['total_due'] as double).compareTo(a['total_due'] as double));
    return rows;
  }
}
