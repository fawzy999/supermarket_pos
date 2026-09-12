import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../models/supply_batch.dart';

class SupplyBatchRepository {
  final _db = AppDatabase.instance;

  /// بيسجل دفعة توريد جديدة، ويضيف كميتها فوق كمية الصنف الحالية
  /// (من غير ما يمسح أو يستبدل أي حاجة قديمة)
  Future<int> recordSupplyBatch({
    required int productId,
    int? supplierId,
    required double quantity,
    required String supplyDate,
    String? expiryDate,
    String? receivedBy,
    String? notes,
    String? invoiceImagePath,
    String? receiptImagePath,
  }) async {
    late int batchId;

    await _db.database.transaction((txn) async {
      // 1. تسجيل الدفعة كسطر مستقل
      batchId = await txn.insert('supply_batches', {
        'product_id': productId,
        'supplier_id': supplierId,
        'quantity_received': quantity,
        'remaining_quantity': quantity,
        'supply_date': supplyDate,
        'expiry_date': expiryDate,
        'received_by': receivedBy,
        'notes': notes,
        'invoice_image_path': invoiceImagePath,
        'receipt_image_path': receiptImagePath,
      });

      // 2. إضافة الكمية فوق كمية الصنف الحالية (مش استبدال)
      await txn.rawUpdate(
        'UPDATE products SET quantity = quantity + ? WHERE id = ?',
        [quantity, productId],
      );

      // 3. تسجيل حركة الدخول في سجل تتبع المخزون
      // ملحوظة: بنسجل تاريخ ووقت لحظة إدخال العملية فعليًا (DateTime.now)،
      // مش تاريخ التوريد المُختار من المستخدم (اللي ممكن يكون تاريخ فاضي
      // من الوقت، أو تاريخ سابق بيتم إدخاله متأخر) - عشان سجل الحركة يفضل
      // دقيق بالساعة والدقيقة لأي مراجعة أو تدقيق لاحق
      await txn.insert('inventory_movements', {
        'product_id': productId,
        'type': 'in',
        'quantity': quantity,
        'reference_id': batchId,
        'date': DateTime.now().toIso8601String(),
      });
    });

    return batchId;
  }

  /// بيخصم كمية مباعة من دفعات التوريد بنظام FIFO (الدفعة الأقرب انتهاء صلاحية
  /// بتتخصم أولًا). لازم تتنفذ جوه نفس معاملة (transaction) عملية البيع، عشان
  /// خصم الدفعات وخصم إجمالي كمية الصنف يحصلوا مع بعض أو يترجعوا مع بعض لو
  /// حصل خطأ في أي خطوة من عملية البيع.
  ///
  /// ده هو الإصلاح لمشكلة إن "الكمية المتبقية" في شاشة توريدات الصنف
  /// كانت بتفضل زي ما هي بعد عمليات البيع، لأن الخصم كان بيحصل بس على
  /// إجمالي كمية الصنف (products.quantity) من غير ما يلمس جدول الدفعات.
  Future<void> deductFifo({
    required DatabaseExecutor txn,
    required int productId,
    required double quantity,
  }) async {
    var remainingToDeduct = quantity;
    if (remainingToDeduct <= 0) return;

    final batches = await txn.query(
      'supply_batches',
      where: 'product_id = ? AND remaining_quantity > 0',
      whereArgs: [productId],
      orderBy: '(expiry_date IS NULL), expiry_date ASC, supply_date ASC',
    );

    for (final batch in batches) {
      if (remainingToDeduct <= 0) break;

      final batchId = batch['id'] as int;
      final batchRemaining = (batch['remaining_quantity'] as num).toDouble();
      final deductFromThisBatch =
          batchRemaining >= remainingToDeduct ? remainingToDeduct : batchRemaining;

      await txn.rawUpdate(
        'UPDATE supply_batches SET remaining_quantity = remaining_quantity - ? WHERE id = ?',
        [deductFromThisBatch, batchId],
      );

      remainingToDeduct -= deductFromThisBatch;
    }

    // لو فضلت كمية متخصمتش (يعني مفيش دفعات مسجلة كفاية لتغطية الكمية
    // المباعة)، بيتم تجاهلها هنا عمدًا: إجمالي كمية الصنف (products.quantity)
    // هو المرجع الأساسي للمخزون المتاح، والفرق هنا مجرد قصور في تتبع
    // الدفعات (مثلاً بضاعة مسجلة أصلًا من غير دفعة توريد)، مش خطأ يوقف البيع.
  }

  /// كل دفعات التوريد لصنف معين، الأقرب انتهاء صلاحية أولًا (نظام FIFO)
  Future<List<Map<String, dynamic>>> getBatchesForProduct(int productId) async {
    return _db.database.rawQuery('''
      SELECT supply_batches.*, suppliers.company_name as supplier_name
      FROM supply_batches
      LEFT JOIN suppliers ON suppliers.id = supply_batches.supplier_id
      WHERE supply_batches.product_id = ?
      ORDER BY (supply_batches.expiry_date IS NULL), supply_batches.expiry_date ASC
    ''', [productId]);
  }

  /// كل الدفعات القريبة من انتهاء الصلاحية خلال عدد أيام معين (بدون
  /// الدفعات المنتهية فعلًا - دي بتستخدم غالبًا داخل شاشات تانية زي شاشة
  /// المخزون الرئيسية للتنبيه السريع)
  Future<List<Map<String, dynamic>>> getBatchesNearExpiry({int withinDays = 7}) async {
    final cutoff = DateTime.now().add(Duration(days: withinDays)).toIso8601String().substring(0, 10);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return _db.database.rawQuery('''
      SELECT supply_batches.*, products.name as product_name, suppliers.company_name as supplier_name
      FROM supply_batches
      JOIN products ON products.id = supply_batches.product_id
      LEFT JOIN suppliers ON suppliers.id = supply_batches.supplier_id
      WHERE supply_batches.expiry_date IS NOT NULL
        AND supply_batches.expiry_date <= ?
        AND supply_batches.expiry_date >= ?
        AND supply_batches.remaining_quantity > 0
      ORDER BY supply_batches.expiry_date ASC
    ''', [cutoff, today]);
  }

  /// كل تنبيهات الصلاحية: الدفعات المنتهية فعلًا + القريبة من الانتهاء
  /// خلال عدد أيام معين، مع علامة is_expired لتمييز الحالتين في الشاشة.
  /// ده أساس موديول "تنبيهات انتهاء الصلاحية" المستقل.
  Future<List<Map<String, dynamic>>> getExpiryAlerts({int withinDays = 7}) async {
    final cutoff = DateTime.now().add(Duration(days: withinDays)).toIso8601String().substring(0, 10);

    final rows = await _db.database.rawQuery('''
      SELECT supply_batches.*, products.name as product_name, suppliers.company_name as supplier_name
      FROM supply_batches
      JOIN products ON products.id = supply_batches.product_id
      LEFT JOIN suppliers ON suppliers.id = supply_batches.supplier_id
      WHERE supply_batches.expiry_date IS NOT NULL
        AND supply_batches.expiry_date <= ?
        AND supply_batches.remaining_quantity > 0
      ORDER BY supply_batches.expiry_date ASC
    ''', [cutoff]);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    return rows
        .map((r) => {
              ...r,
              'is_expired': (r['expiry_date'] as String).substring(0, 10).compareTo(today) < 0,
            })
        .toList();
  }
}
