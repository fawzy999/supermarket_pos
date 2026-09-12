import '../../../core/database/app_database.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/barcode_generator.dart';

class InventoryRepository {
  final _db = AppDatabase.instance;

  // ---------------- الفئات ----------------

  Future<List<Category>> getCategories() async {
    final rows = await _db.database.query('categories', orderBy: 'name');
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  Future<int> addCategory(Category category) async {
    return _db.database.insert('categories', category.toMap());
  }

  /// كل الفئات + عدد الأصناف في كل واحدة (بما فيهم "غير مصنّف")
  Future<List<Map<String, dynamic>>> getCategoriesWithCounts() async {
    final rows = await _db.database.rawQuery('''
      SELECT categories.id, categories.name, COUNT(products.id) as product_count
      FROM categories
      LEFT JOIN products ON products.category_id = categories.id
      GROUP BY categories.id
      ORDER BY categories.name
    ''');

    final uncategorizedResult = await _db.database.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE category_id IS NULL',
    );
    final uncategorizedCount = (uncategorizedResult.first['count'] as int?) ?? 0;

    return [
      ...rows,
      if (uncategorizedCount > 0)
        {'id': null, 'name': 'غير مصنّف', 'product_count': uncategorizedCount},
    ];
  }

  /// أصناف فئة معينة - لو categoryId فاضي، بيرجع الأصناف "غير المصنّفة"
  Future<List<Product>> getProductsByCategory(int? categoryId, {String? searchQuery}) async {
    final whereClause = categoryId == null ? 'category_id IS NULL' : 'category_id = ?';
    final whereArgs = categoryId == null ? <Object>[] : [categoryId];

    List<Map<String, dynamic>> rows;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      rows = await _db.database.query(
        'products',
        where: '$whereClause AND (name LIKE ? OR barcode LIKE ?)',
        whereArgs: [...whereArgs, '%$searchQuery%', '%$searchQuery%'],
        orderBy: 'name',
      );
    } else {
      rows = await _db.database.query('products', where: whereClause, whereArgs: whereArgs, orderBy: 'name');
    }
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  // ---------------- المنتجات ----------------

  Future<List<Product>> getAllProducts({String? searchQuery}) async {
    List<Map<String, dynamic>> rows;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      rows = await _db.database.query(
        'products',
        where: 'name LIKE ? OR barcode LIKE ?',
        whereArgs: ['%$searchQuery%', '%$searchQuery%'],
        orderBy: 'name',
      );
    } else {
      rows = await _db.database.query('products', orderBy: 'name');
    }
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final rows = await _db.database.query('products', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final rows = await _db.database.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<int> addProduct(Product product) async {
    final id = await _db.database.insert('products', product.toMap());

    // لو الباركود فاضي، نولّد واحد تلقائيًا مبني على رقم الصنف
    if (product.barcode == null || product.barcode!.trim().isEmpty) {
      final generatedBarcode = BarcodeGenerator.generateForProductId(id);
      await _db.database.update(
        'products',
        {'barcode': generatedBarcode},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    // تسجيل حركة الدخول الأولى في سجل تتبع المخزون
    if (product.quantity > 0) {
      await _logMovement(
        productId: id,
        type: 'in',
        quantity: product.quantity,
        referenceId: null,
      );
    }
    return id;
  }

  Future<void> updateProduct(Product product) async {
    await _db.database.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(int productId) async {
    await _db.database.delete(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// تسوية جرد يدوية: بتحدّث الكمية وتسجل الفرق في حركة المخزون
  Future<void> adjustQuantity(int productId, double newQuantity) async {
    final rows = await _db.database.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final currentQuantity = (rows.first['quantity'] as num).toDouble();
    final difference = newQuantity - currentQuantity;

    await _db.database.update(
      'products',
      {'quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [productId],
    );

    if (difference != 0) {
      await _logMovement(
        productId: productId,
        type: 'adjustment',
        quantity: difference,
        referenceId: null,
      );
    }
  }

  /// سجل حركة المخزون (دخول/خروج/تعديل) بالتاريخ والوقت، مع اسم الصنف.
  /// لو productId اتبعت، بيرجع حركة الصنف ده بس، وإلا بيرجع كل الحركات.
  Future<List<Map<String, dynamic>>> getMovementHistory({int? productId, int limit = 300}) async {
    return _db.database.rawQuery('''
      SELECT inventory_movements.*, products.name as product_name
      FROM inventory_movements
      JOIN products ON products.id = inventory_movements.product_id
      ${productId != null ? 'WHERE inventory_movements.product_id = ?' : ''}
      ORDER BY inventory_movements.date DESC, inventory_movements.id DESC
      LIMIT ?
    ''', [if (productId != null) productId, limit]);
  }

  Future<List<Product>> getLowStockProducts() async {
    final rows = await _db.database.rawQuery(
      'SELECT * FROM products WHERE quantity <= reorder_level ORDER BY name',
    );
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<void> _logMovement({
    required int productId,
    required String type,
    required double quantity,
    int? referenceId,
  }) async {
    await _db.database.insert('inventory_movements', {
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'reference_id': referenceId,
      'date': DateTime.now().toIso8601String(),
    });
  }
}
