import '../../../core/database/app_database.dart';
import '../models/supplier.dart';
import '../models/supplier_contact.dart';

class SupplierRepository {
  final _db = AppDatabase.instance;

  Future<List<Supplier>> getAllSuppliers({String? searchQuery}) async {
    List<Map<String, dynamic>> rows;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      rows = await _db.database.query(
        'suppliers',
        where: 'company_name LIKE ? OR phone LIKE ? OR email LIKE ?',
        whereArgs: ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%'],
        orderBy: 'company_name',
      );
    } else {
      rows = await _db.database.query('suppliers', orderBy: 'company_name');
    }
    return rows.map((r) => Supplier.fromMap(r)).toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    final rows = await _db.database.query('suppliers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Supplier.fromMap(rows.first);
  }

  Future<int> addSupplier(Supplier supplier) async {
    return _db.database.insert('suppliers', supplier.toMap());
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _db.database.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  /// كل التوريدات اللي جابها مورد معين، مع اسم الصنف
  Future<List<Map<String, dynamic>>> getBatchesForSupplier(int supplierId) async {
    return _db.database.rawQuery('''
      SELECT supply_batches.*, products.name as product_name
      FROM supply_batches
      JOIN products ON products.id = supply_batches.product_id
      WHERE supply_batches.supplier_id = ?
      ORDER BY supply_batches.supply_date DESC
    ''', [supplierId]);
  }

  // ---------------- أشخاص التواصل عند المورد ----------------

  Future<List<SupplierContact>> getContactsForSupplier(int supplierId) async {
    final rows = await _db.database.query(
      'supplier_contacts',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'id',
    );
    return rows.map((r) => SupplierContact.fromMap(r)).toList();
  }

  Future<int> addContact(SupplierContact contact) async {
    return _db.database.insert('supplier_contacts', contact.toMap());
  }

  Future<void> updateContact(SupplierContact contact) async {
    await _db.database.update(
      'supplier_contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<void> deleteContact(int id) async {
    await _db.database.delete('supplier_contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- مستندات المورد (عقود/فواتير توريد/إلخ - عدد غير محدود) ----------------

  Future<List<Map<String, dynamic>>> getDocumentsForSupplier(int supplierId) async {
    return _db.database.query(
      'supplier_documents',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'uploaded_at DESC',
    );
  }

  Future<int> addDocument({
    required int supplierId,
    required String docType,
    String? title,
    required String filePath,
    String? expiryDate,
  }) {
    return _db.database.insert('supplier_documents', {
      'supplier_id': supplierId,
      'doc_type': docType,
      'title': title,
      'file_path': filePath,
      'uploaded_at': DateTime.now().toIso8601String(),
      'expiry_date': expiryDate,
    });
  }

  Future<void> deleteDocument(int id) =>
      _db.database.delete('supplier_documents', where: 'id = ?', whereArgs: [id]);

  /// مستندات موردين منتهية أو قربت تنتهي خلال كذا يوم - لشاشة "التذكيرات"
  Future<List<Map<String, dynamic>>> getExpiringDocuments({int withinDays = 30}) async {
    final cutoff = DateTime.now().add(Duration(days: withinDays)).toIso8601String();
    return _db.database.rawQuery('''
      SELECT supplier_documents.*, suppliers.company_name, suppliers.phone
      FROM supplier_documents
      JOIN suppliers ON suppliers.id = supplier_documents.supplier_id
      WHERE supplier_documents.expiry_date IS NOT NULL AND supplier_documents.expiry_date <= ?
      ORDER BY supplier_documents.expiry_date ASC
    ''', [cutoff]);
  }

  // ---------------- حساب المورد: رصيد مستحق + كشف حساب (مديونية/دفعة) ----------------

  /// تسجيل مديونية جديدة (فاتورة/توريد بالأجل) - بتزوّد الرصيد المستحق للمورد
  Future<void> recordDebt({
    required int supplierId,
    required double amount,
    String? notes,
    String? recordedBy,
    int? contractId,
  }) async {
    await _db.database.transaction((txn) async {
      await txn.insert('supplier_transactions', {
        'supplier_id': supplierId,
        'type': 'debt',
        'amount': amount,
        'notes': notes,
        'recorded_by': recordedBy,
        'contract_id': contractId,
        'date': DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate(
        'UPDATE suppliers SET balance = balance + ? WHERE id = ?',
        [amount, supplierId],
      );
    });
  }

  /// تسجيل دفعة (سداد) للمورد - بتنقّص الرصيد المستحق
  Future<void> recordPayment({
    required int supplierId,
    required double amount,
    String? notes,
    String? recordedBy,
    int? contractId,
  }) async {
    await _db.database.transaction((txn) async {
      await txn.insert('supplier_transactions', {
        'supplier_id': supplierId,
        'type': 'payment',
        'amount': amount,
        'notes': notes,
        'recorded_by': recordedBy,
        'contract_id': contractId,
        'date': DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate(
        'UPDATE suppliers SET balance = balance - ? WHERE id = ?',
        [amount, supplierId],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getLedgerForSupplier(int supplierId) async {
    return _db.database.query(
      'supplier_transactions',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'date DESC',
    );
  }

  /// كل الموردين اللي ليهم رصيد مستحق (موجب) - لقسم "الأرصدة" بالحسابات الرئيسية
  Future<List<Supplier>> getSuppliersWithBalance() async {
    final rows = await _db.database.query(
      'suppliers',
      where: 'balance != 0',
      orderBy: 'balance DESC',
    );
    return rows.map((r) => Supplier.fromMap(r)).toList();
  }

  Future<double> getTotalPayable() async {
    final result = await _db.database.rawQuery(
      "SELECT COALESCE(SUM(balance), 0) as total FROM suppliers WHERE balance > 0",
    );
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  // ---------------- عقود التوريد (اختياري لكل مورد) ----------------

  Future<int> createContract({
    required int supplierId,
    required String title,
    required double totalAmount,
    String? startDate,
    String? endDate,
    String? durationLabel,
    String? quoteFilePath,
    String? contractFilePath,
    String? notes,
    List<Map<String, dynamic>> items = const [],
  }) async {
    late int contractId;
    await _db.database.transaction((txn) async {
      contractId = await txn.insert('supplier_contracts', {
        'supplier_id': supplierId,
        'title': title,
        'total_amount': totalAmount,
        'start_date': startDate,
        'end_date': endDate,
        'duration_label': durationLabel,
        'quote_file_path': quoteFilePath,
        'contract_file_path': contractFilePath,
        'notes': notes,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final item in items) {
        await txn.insert('supplier_contract_items', {
          'contract_id': contractId,
          'product_id': item['product_id'],
          'item_name': item['item_name'],
          'category_name': item['category_name'],
          'unit': item['unit'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
        });
      }

      // قيمة العقد بالكامل = مديونية على المحل تجاه المورد، هتتنقّص تدريجيًا
      // مع كل قسط بيتسجل مدفوع
      await txn.insert('supplier_transactions', {
        'supplier_id': supplierId,
        'type': 'debt',
        'amount': totalAmount,
        'notes': 'عقد توريد: $title',
        'recorded_by': null,
        'contract_id': contractId,
        'date': DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate(
        'UPDATE suppliers SET balance = balance + ? WHERE id = ?',
        [totalAmount, supplierId],
      );
    });
    return contractId;
  }

  Future<List<Map<String, dynamic>>> getContractsForSupplier(int supplierId) async {
    final contracts = await _db.database.query(
      'supplier_contracts',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'created_at DESC',
    );
    final result = <Map<String, dynamic>>[];
    for (final contract in contracts) {
      final paidResult = await _db.database.rawQuery(
        'SELECT COALESCE(SUM(amount_paid), 0) as total FROM supplier_contract_installments WHERE contract_id = ?',
        [contract['id']],
      );
      final paid = (paidResult.first['total'] as num).toDouble();
      result.add({...contract, 'paid_total': paid});
    }
    return result;
  }

  /// أصناف عقد توريد معين - كل صنف مربوط بمنتج مسجّل (أو صنف يدوي)
  /// بفئته وكميته وسعره وقت توقيع العقد
  Future<List<Map<String, dynamic>>> getItemsForContract(int contractId) async {
    return _db.database.query(
      'supplier_contract_items',
      where: 'contract_id = ?',
      whereArgs: [contractId],
      orderBy: 'id',
    );
  }

  Future<int> addInstallment({
    required int contractId,
    String? dueDate,
    required double amountDue,
    String? notes,
  }) {
    return _db.database.insert('supplier_contract_installments', {
      'contract_id': contractId,
      'due_date': dueDate,
      'amount_due': amountDue,
      'amount_paid': 0,
      'status': 'pending',
      'notes': notes,
    });
  }

  Future<List<Map<String, dynamic>>> getInstallments(int contractId) async {
    return _db.database.query(
      'supplier_contract_installments',
      where: 'contract_id = ?',
      whereArgs: [contractId],
      orderBy: '(due_date IS NULL), due_date ASC',
    );
  }

  /// تسجيل دفعة على قسط معين (كليًا أو جزئيًا) - بتترحّل تلقائيًا كدفعة
  /// في كشف حساب المورد العام وتنقّص رصيده المستحق
  Future<void> payInstallment({
    required int installmentId,
    required int supplierId,
    required double amount,
    String? notes,
  }) async {
    await _db.database.transaction((txn) async {
      final rows = await txn.query(
        'supplier_contract_installments',
        where: 'id = ?',
        whereArgs: [installmentId],
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      final amountDue = (row['amount_due'] as num).toDouble();
      final currentPaid = (row['amount_paid'] as num).toDouble();
      final newPaid = currentPaid + amount;
      final status = newPaid >= amountDue ? 'paid' : (newPaid > 0 ? 'partial' : 'pending');

      await txn.update(
        'supplier_contract_installments',
        {
          'amount_paid': newPaid,
          'status': status,
          'paid_date': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [installmentId],
      );

      await txn.insert('supplier_transactions', {
        'supplier_id': supplierId,
        'type': 'payment',
        'amount': amount,
        'notes': notes ?? 'سداد قسط من عقد توريد',
        'recorded_by': null,
        'contract_id': row['contract_id'],
        'date': DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate(
        'UPDATE suppliers SET balance = balance - ? WHERE id = ?',
        [amount, supplierId],
      );
    });
  }

  /// كل أقساط عقود التوريد المستحقة خلال كذا يوم جاي أو المتأخرة فعلًا
  /// (لسه مش مدفوعة بالكامل) - لشاشة "التذكيرات"
  Future<List<Map<String, dynamic>>> getDueOrOverdueInstallments({int withinDays = 3}) async {
    final cutoff = DateTime.now().add(Duration(days: withinDays)).toIso8601String();
    return _db.database.rawQuery('''
      SELECT supplier_contract_installments.*, supplier_contracts.title as contract_title,
             suppliers.id as supplier_id, suppliers.company_name, suppliers.phone
      FROM supplier_contract_installments
      JOIN supplier_contracts ON supplier_contracts.id = supplier_contract_installments.contract_id
      JOIN suppliers ON suppliers.id = supplier_contracts.supplier_id
      WHERE supplier_contract_installments.status != 'paid'
        AND supplier_contract_installments.due_date IS NOT NULL
        AND supplier_contract_installments.due_date <= ?
      ORDER BY supplier_contract_installments.due_date ASC
    ''', [cutoff]);
  }
}
