import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// نقطة الوصول الوحيدة لقاعدة البيانات المحلية (Singleton)
/// كل الموديولات (مخزون، مبيعات، محاسبة...) بتستخدم نفس النسخة دي
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  Database? _db;
  String? _dbPath;

  Database get database {
    if (_db == null) {
      throw StateError('لازم تنادي initialize() قبل استخدام قاعدة البيانات');
    }
    return _db!;
  }

  /// مسار ملف قاعدة البيانات على الجهاز - يُستخدم في النسخ الاحتياطي
  String get databasePath {
    if (_dbPath == null) {
      throw StateError('لازم تنادي initialize() قبل استخدام قاعدة البيانات');
    }
    return _dbPath!;
  }

  Future<void> initialize() async {
    if (_db != null) return;

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = join(directory.path, 'supermarket_pos.db');
    _dbPath = dbPath;

    _db = await openDatabase(
      dbPath,
      version: 20,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  /// بيقفل الاتصال الحالي بقاعدة البيانات - ضروري قبل استبدال الملف عند الاستيراد
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// بيعيد فتح قاعدة البيانات بعد الاستيراد (نفس مسار الملف، من غير إعادة إنشاء الجداول)
  Future<void> reopen() async {
    if (_dbPath == null) {
      throw StateError('لازم initialize() الأول قبل reopen()');
    }
    _db = await openDatabase(_dbPath!, version: 20, onUpgrade: _upgradeDatabase);
  }

  /// ترقية قاعدة بيانات موجودة بالفعل (لعملاء ثبّتوا نسخة قديمة من التطبيق)
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE sales ADD COLUMN customer_name TEXT');
      await db.execute('ALTER TABLE sales ADD COLUMN customer_phone TEXT');
    }
    if (oldVersion < 3) {
      // جدول users القديم كان فيه pin_code بس - نحوله للنظام الجديد
      await db.execute('DROP TABLE IF EXISTS users');
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          username TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'cashier',
          active INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await _seedDefaultAdmin(db);
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE shifts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          login_time TEXT NOT NULL,
          logout_time TEXT,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE daily_closings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          closing_date TEXT NOT NULL UNIQUE,
          invoice_count INTEGER NOT NULL DEFAULT 0,
          total_revenue REAL NOT NULL DEFAULT 0,
          total_profit REAL NOT NULL DEFAULT 0,
          total_expenses REAL NOT NULL DEFAULT 0,
          cash_total REAL NOT NULL DEFAULT 0,
          card_total REAL NOT NULL DEFAULT 0,
          closed_by INTEGER,
          closed_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      // إصلاح هاش كلمة السر الافتراضية اللي كان متسجل ناقص حرف بالغلط
      // (أي نسخة اتثبتت قبل التصحيح ده هتتظبط تلقائيًا)
      const correctHash =
          '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9';
      await db.update(
        'users',
        {'password_hash': correctHash},
        where: 'username = ?',
        whereArgs: ['admin'],
      );
    }
    if (oldVersion < 7) {
      final columns = await db.rawQuery('PRAGMA table_info(products)');
      final existingColumns = columns.map((c) => c['name'] as String).toSet();

      if (!existingColumns.contains('packaging_type')) {
        await db.execute('ALTER TABLE products ADD COLUMN packaging_type TEXT');
      }
      if (!existingColumns.contains('units_per_package')) {
        await db.execute('ALTER TABLE products ADD COLUMN units_per_package REAL');
      }
      if (!existingColumns.contains('inner_count')) {
        await db.execute('ALTER TABLE products ADD COLUMN inner_count REAL');
      }
      if (!existingColumns.contains('inner_size')) {
        await db.execute('ALTER TABLE products ADD COLUMN inner_size REAL');
      }
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          company_name TEXT NOT NULL,
          contact_person TEXT,
          phone TEXT,
          address TEXT,
          notes TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE supply_batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          supplier_id INTEGER,
          quantity_received REAL NOT NULL,
          remaining_quantity REAL NOT NULL,
          supply_date TEXT NOT NULL,
          expiry_date TEXT,
          received_by TEXT,
          notes TEXT,
          FOREIGN KEY (product_id) REFERENCES products (id),
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
        )
      ''');
    }
    if (oldVersion < 9) {
      final productColumns = await db.rawQuery('PRAGMA table_info(products)');
      final existingProductColumns = productColumns.map((c) => c['name'] as String).toSet();
      if (!existingProductColumns.contains('image_path')) {
        await db.execute('ALTER TABLE products ADD COLUMN image_path TEXT');
      }

      final shiftColumns = await db.rawQuery('PRAGMA table_info(shifts)');
      final existingShiftColumns = shiftColumns.map((c) => c['name'] as String).toSet();
      final shiftColumnsToAdd = {
        'invoice_count': 'INTEGER',
        'cash_total': 'REAL',
        'card_total': 'REAL',
        'total_amount': 'REAL',
        'confirmed_by': 'INTEGER',
        'confirmed_at': 'TEXT',
      };
      for (final entry in shiftColumnsToAdd.entries) {
        if (!existingShiftColumns.contains(entry.key)) {
          await db.execute('ALTER TABLE shifts ADD COLUMN ${entry.key} ${entry.value}');
        }
      }
    }
    if (oldVersion < 10) {
      // ---------- موديول العملاء (CRM) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          notes TEXT,
          balance REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          notes TEXT,
          received_by TEXT,
          FOREIGN KEY (customer_id) REFERENCES customers (id)
        )
      ''');

      final salesColumns = await db.rawQuery('PRAGMA table_info(sales)');
      final existingSalesColumns = salesColumns.map((c) => c['name'] as String).toSet();
      if (!existingSalesColumns.contains('customer_id')) {
        await db.execute('ALTER TABLE sales ADD COLUMN customer_id INTEGER');
      }

      // ---------- موديول المرتجعات (عملاء وموردين) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS returns (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          product_id INTEGER NOT NULL,
          quantity REAL NOT NULL,
          unit_price REAL,
          reference_sale_id INTEGER,
          supplier_id INTEGER,
          batch_id INTEGER,
          reason TEXT,
          date TEXT NOT NULL,
          processed_by TEXT,
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');

      // تسجيل الموديولات الجديدة (عملاء، مرتجعات، تنبيهات صلاحية) عشان
      // تظهر فورًا في الشاشة الرئيسية للعملاء اللي عندهم نسخة مثبتة بالفعل
      await _registerModule(db, key: 'customers', nameAr: 'العملاء', minTier: 'pro');
      await _registerModule(db, key: 'returns', nameAr: 'المرتجعات', minTier: 'pro');
      await _registerModule(db, key: 'expiry_alerts', nameAr: 'تنبيهات الصلاحية', minTier: 'basic');
    }
    if (oldVersion < 11) {
      // ---------- تصوير فاتورة المصروف ----------
      final expenseColumns = await db.rawQuery('PRAGMA table_info(expenses)');
      final existingExpenseColumns = expenseColumns.map((c) => c['name'] as String).toSet();
      if (!existingExpenseColumns.contains('receipt_image_path')) {
        await db.execute('ALTER TABLE expenses ADD COLUMN receipt_image_path TEXT');
      }

      // ---------- بيانات موردين تفصيلية (إيميل + صورة كارت الشركة) ----------
      final supplierColumns = await db.rawQuery('PRAGMA table_info(suppliers)');
      final existingSupplierColumns = supplierColumns.map((c) => c['name'] as String).toSet();
      if (!existingSupplierColumns.contains('email')) {
        await db.execute('ALTER TABLE suppliers ADD COLUMN email TEXT');
      }
      if (!existingSupplierColumns.contains('logo_path')) {
        await db.execute('ALTER TABLE suppliers ADD COLUMN logo_path TEXT');
      }

      // ---------- أشخاص التواصل عند المورد (أكتر من شخص لكل مورد) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_contacts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          role TEXT,
          phone TEXT,
          email TEXT,
          notes TEXT,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
        )
      ''');
    }
    if (oldVersion < 12) {
      // ---------- إظهار "الموردين" كصندوق مستقل في الشاشة الرئيسية ----------
      await _registerModule(db, key: 'suppliers', nameAr: 'الموردين', minTier: 'basic');

      // ---------- موديول المناديب والشحن ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reps (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          national_id TEXT,
          address TEXT,
          photo_path TEXT,
          notes TEXT,
          active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');

      // سجل حركة عهدة كل مندوب: سحب من المخزون الرئيسي / إرجاع الفائض /
      // خصم عند البيع الخارجي / تسوية (فرق جرد دوري)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rep_custody (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rep_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          type TEXT NOT NULL, -- withdraw / return / sale / adjustment
          quantity REAL NOT NULL,
          reference_id INTEGER,
          notes TEXT,
          date TEXT NOT NULL,
          FOREIGN KEY (rep_id) REFERENCES reps (id),
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');

      // فواتير البيع الخارجي (من عهدة المندوب، مش من مخزون المحل مباشرة)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rep_sales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rep_id INTEGER NOT NULL,
          customer_id INTEGER,
          customer_name TEXT,
          customer_phone TEXT,
          payment_method TEXT NOT NULL DEFAULT 'cash',
          total_amount REAL NOT NULL DEFAULT 0,
          notes TEXT,
          date TEXT NOT NULL,
          FOREIGN KEY (rep_id) REFERENCES reps (id),
          FOREIGN KEY (customer_id) REFERENCES customers (id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rep_sale_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rep_sale_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity REAL NOT NULL,
          unit_price REAL NOT NULL,
          FOREIGN KEY (rep_sale_id) REFERENCES rep_sales (id),
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');

      // طلبات التوصيل: ربط فاتورة بيع من المحل بمندوب لتوصيلها
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rep_deliveries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rep_id INTEGER NOT NULL,
          sale_id INTEGER,
          customer_name TEXT,
          customer_phone TEXT,
          address TEXT,
          status TEXT NOT NULL DEFAULT 'pending', -- pending / delivered / returned / postponed
          notes TEXT,
          assigned_at TEXT NOT NULL,
          delivered_at TEXT,
          FOREIGN KEY (rep_id) REFERENCES reps (id),
          FOREIGN KEY (sale_id) REFERENCES sales (id)
        )
      ''');

      // تحصيلات جمعها المندوب من عملاء (بتتربط بموديول CRM تلقائيًا)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rep_collections (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rep_id INTEGER NOT NULL,
          customer_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          notes TEXT,
          date TEXT NOT NULL,
          FOREIGN KEY (rep_id) REFERENCES reps (id),
          FOREIGN KEY (customer_id) REFERENCES customers (id)
        )
      ''');

      // تسوية دورية (مطابقة عهدة المندوب - جولة/يوم)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rep_settlements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rep_id INTEGER NOT NULL,
          notes TEXT,
          settled_by TEXT,
          date TEXT NOT NULL,
          FOREIGN KEY (rep_id) REFERENCES reps (id)
        )
      ''');

      await _registerModule(db, key: 'reps', nameAr: 'المناديب والشحن', minTier: 'pro');
    }
    if (oldVersion < 13) {
      // ---------- موديول الموظفين: بيانات كاملة + مستندات ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS employees (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          national_id TEXT,
          address TEXT,
          position TEXT,
          qualification TEXT,
          salary_type TEXT NOT NULL DEFAULT 'monthly', -- monthly / daily
          base_salary REAL NOT NULL DEFAULT 0,
          hire_date TEXT,
          photo_path TEXT,
          national_id_image_path TEXT,
          qualification_doc_path TEXT,
          address_proof_path TEXT,
          notes TEXT,
          active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');

      // مستندات إضافية متعددة لكل موظف (عقد، شهادات، إلخ)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS employee_documents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER NOT NULL,
          title TEXT,
          file_path TEXT NOT NULL,
          uploaded_at TEXT NOT NULL,
          FOREIGN KEY (employee_id) REFERENCES employees (id)
        )
      ''');

      // الحضور والانصراف
      await db.execute('''
        CREATE TABLE IF NOT EXISTS employee_attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          check_in TEXT,
          check_out TEXT,
          status TEXT NOT NULL DEFAULT 'present', -- present / absent / leave / late
          notes TEXT,
          FOREIGN KEY (employee_id) REFERENCES employees (id)
        )
      ''');

      // المرتبات واليوميات (سجل كل صرف فعلي للموظف)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS employee_payroll (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER NOT NULL,
          period_label TEXT NOT NULL,
          base_amount REAL NOT NULL DEFAULT 0,
          bonuses REAL NOT NULL DEFAULT 0,
          deductions REAL NOT NULL DEFAULT 0,
          net_amount REAL NOT NULL DEFAULT 0,
          notes TEXT,
          paid_by TEXT,
          paid_at TEXT NOT NULL,
          FOREIGN KEY (employee_id) REFERENCES employees (id)
        )
      ''');

      await _registerModule(db, key: 'hr', nameAr: 'الموظفين', minTier: 'pro');

      // ---------- الأجهزة المتصلة (طابعات/شاشات عرض/سكانرات) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS connected_devices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'printer', -- printer / customer_display / scanner / other
          connection_type TEXT NOT NULL DEFAULT 'bluetooth', -- bluetooth / wifi / usb
          address TEXT, -- MAC أو IP حسب نوع الاتصال
          is_default INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'unknown', -- connected / disconnected / unknown / error
          last_checked_at TEXT,
          notes TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      // ---------- صلاحيات كل مستخدم لكل موديول (فوق التفعيل العام) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_permissions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          module_key TEXT NOT NULL,
          allowed INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (user_id) REFERENCES users (id),
          UNIQUE(user_id, module_key)
        )
      ''');
    }

    if (oldVersion < 14) {
      // ---------- إيميل المندوب + عقد الموظف ----------
      await db.execute('ALTER TABLE reps ADD COLUMN email TEXT');
      await db.execute('ALTER TABLE employees ADD COLUMN contract_doc_path TEXT');

      // ---------- مستندات مرنة غير محدودة للمندوب (بطاقة/عنوان/شهادة/عقد/إضافي) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rep_documents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rep_id INTEGER NOT NULL,
          doc_type TEXT NOT NULL DEFAULT 'other',
          title TEXT,
          file_path TEXT NOT NULL,
          uploaded_at TEXT NOT NULL,
          FOREIGN KEY (rep_id) REFERENCES reps (id)
        )
      ''');

      // ---------- مستندات مرنة غير محدودة للمورد (عقود/فواتير/إلخ) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_documents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          doc_type TEXT NOT NULL DEFAULT 'other',
          title TEXT,
          file_path TEXT NOT NULL,
          uploaded_at TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
        )
      ''');

      // ---------- صورة فاتورة المورد + صورة استلام البضاعة لكل توريدة ----------
      await db.execute('ALTER TABLE supply_batches ADD COLUMN invoice_image_path TEXT');
      await db.execute('ALTER TABLE supply_batches ADD COLUMN receipt_image_path TEXT');

      // ---------- رصيد المورد (المستحق له من المحل) ----------
      await db.execute('ALTER TABLE suppliers ADD COLUMN balance REAL NOT NULL DEFAULT 0');

      // ---------- كشف حساب المورد: مديونية (فاتورة/توريد بالأجل) أو دفعة ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          type TEXT NOT NULL, -- debt (زيادة المستحق) / payment (سداد)
          amount REAL NOT NULL,
          notes TEXT,
          recorded_by TEXT,
          contract_id INTEGER,
          date TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
        )
      ''');

      // ---------- عقود التوريد (اختياري لكل مورد) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_contracts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          total_amount REAL NOT NULL DEFAULT 0,
          start_date TEXT,
          notes TEXT,
          status TEXT NOT NULL DEFAULT 'active', -- active / completed / cancelled
          created_at TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
        )
      ''');

      // ---------- أقساط/دفعات عقد التوريد (كل قسط له موعد استحقاق) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_contract_installments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contract_id INTEGER NOT NULL,
          due_date TEXT,
          amount_due REAL NOT NULL DEFAULT 0,
          amount_paid REAL NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'pending', -- pending / partial / paid
          paid_date TEXT,
          notes TEXT,
          FOREIGN KEY (contract_id) REFERENCES supplier_contracts (id)
        )
      ''');

      // ---------- مبلغ نقدي مُسلَّم فعليًا في تسوية عهدة المندوب ----------
      await db.execute('ALTER TABLE rep_settlements ADD COLUMN amount REAL NOT NULL DEFAULT 0');
    }

    if (oldVersion < 15) {
      // ---------- العروض التسويقية (تتشارك على واتساب/سوشيال ميديا) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS marketing_offers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          image_path TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      await _registerModule(db, key: 'marketing', nameAr: 'العروض التسويقية', minTier: 'pro');
    }

    if (oldVersion < 16) {
      // ---------- تاريخ صلاحية اختياري لمستندات المندوب/المورد ----------
      await db.execute('ALTER TABLE rep_documents ADD COLUMN expiry_date TEXT');
      await db.execute('ALTER TABLE supplier_documents ADD COLUMN expiry_date TEXT');

      // ---------- نقاط ولاء العملاء ----------
      await db.execute('ALTER TABLE customers ADD COLUMN loyalty_points INTEGER NOT NULL DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_loyalty_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          points INTEGER NOT NULL,
          reason TEXT,
          date TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id)
        )
      ''');
    }

    if (oldVersion < 17) {
      // ---------- خصم على مستوى الفاتورة (بحد أقصى تتحكم فيه الإدارة) ----------
      await db.execute('ALTER TABLE sales ADD COLUMN subtotal_amount REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE sales ADD COLUMN discount_percent REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE sales ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0');
      // الفواتير القديمة قبل الترقية: الإجمالي الفرعي = الإجمالي النهائي (مفيش خصم)
      await db.execute('UPDATE sales SET subtotal_amount = total_amount');

      // ---------- صنف يدوي / خدمة في الفاتورة (بجانب صنف من المخزون) ----------
      // SQLite مايدعمش تعديل قيد NOT NULL مباشرة، فبنعيد بناء الجدول عشان
      // product_id يبقى اختياري (الصنف اليدوي/الخدمة مالوش صف منتج فعلي)
      await db.execute('''
        CREATE TABLE sale_items_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          product_id INTEGER,
          item_type TEXT NOT NULL DEFAULT 'product',
          manual_name TEXT,
          quantity REAL NOT NULL,
          unit_price REAL NOT NULL,
          FOREIGN KEY (sale_id) REFERENCES sales (id),
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');
      await db.execute('''
        INSERT INTO sale_items_new (id, sale_id, product_id, item_type, manual_name, quantity, unit_price)
        SELECT id, sale_id, product_id, 'product', NULL, quantity, unit_price FROM sale_items
      ''');
      await db.execute('DROP TABLE sale_items');
      await db.execute('ALTER TABLE sale_items_new RENAME TO sale_items');

      // ---------- طلبات التوريد/الشراء الاحترافية (PDF + واتساب/إيميل) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER,
          supplier_name TEXT,
          supplier_phone TEXT,
          supplier_email TEXT,
          supplier_address TEXT,
          status TEXT NOT NULL DEFAULT 'draft',
          notes TEXT,
          created_by TEXT,
          date TEXT NOT NULL,
          total_amount REAL NOT NULL DEFAULT 0,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_order_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_order_id INTEGER NOT NULL,
          product_id INTEGER,
          item_name TEXT NOT NULL,
          unit TEXT,
          quantity REAL NOT NULL,
          unit_price REAL NOT NULL DEFAULT 0,
          FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders (id),
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');
    }
    if (oldVersion < 18) {
      // ---------- الدخول بالبصمة ----------
      await db.execute('ALTER TABLE users ADD COLUMN biometric_enabled INTEGER NOT NULL DEFAULT 0');

      // ---------- المبلغ الفعلي المؤكَّد وقت تسليم/استلام العهدة بين مستخدمين ----------
      await db.execute('ALTER TABLE shifts ADD COLUMN received_amount REAL');

      // ---------- سجل معلوماتي بس: كل مرة اتفتح/اتقفل فيها التطبيق (منفصل عن إقفال الوردية نفسها) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_open_close_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          shift_id INTEGER,
          user_id INTEGER,
          event TEXT NOT NULL,
          at TEXT NOT NULL,
          FOREIGN KEY (shift_id) REFERENCES shifts (id),
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');

      // ---------- نقاط استلام نقدية الخزنة (المدير/المحاسب) - checkpoint مستقل عن الورديات ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cash_checkpoints (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          by_user_id INTEGER NOT NULL,
          expected_amount REAL NOT NULL DEFAULT 0,
          actual_amount REAL NOT NULL DEFAULT 0,
          at TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (by_user_id) REFERENCES users (id)
        )
      ''');
    }

    if (oldVersion < 19) {
      // ---------- ربط حساب المستخدم (تسجيل الدخول) بسجل موظف موجود بالـ HR ----------
      await db.execute('ALTER TABLE users ADD COLUMN employee_id INTEGER REFERENCES employees (id)');

      // ---------- عقود التوريد الاحترافية: مدة التوريد والمرفقات (عرض السعر + العقد) ----------
      await db.execute('ALTER TABLE supplier_contracts ADD COLUMN end_date TEXT');
      await db.execute('ALTER TABLE supplier_contracts ADD COLUMN duration_label TEXT');
      await db.execute('ALTER TABLE supplier_contracts ADD COLUMN quote_file_path TEXT');
      await db.execute('ALTER TABLE supplier_contracts ADD COLUMN contract_file_path TEXT');

      // ---------- أصناف عقد التوريد (مربوطة بالمنتجات المسجّلة، أو صنف يدوي) ----------
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_contract_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contract_id INTEGER NOT NULL,
          product_id INTEGER,
          item_name TEXT NOT NULL,
          category_name TEXT,
          unit TEXT,
          quantity REAL NOT NULL DEFAULT 0,
          unit_price REAL NOT NULL DEFAULT 0,
          FOREIGN KEY (contract_id) REFERENCES supplier_contracts (id),
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');
    }

    if (oldVersion < 20) {
      // ---------- ربط فاتورة بيع بمندوب (طريقة الدفع "حساب مندوب") ----------
      await db.execute('ALTER TABLE sales ADD COLUMN rep_id INTEGER REFERENCES reps (id)');

      // ---------- إعدادات صوت الباركود (تفعيل/تعطيل + مستوى الصوت) ----------
      // مفيش عمود جدول جديد - القيم بتتخزن في جدول settings العام
      // الموجود بالفعل (key/value)، فمفيش داعي لأي ALTER هنا
    }
  }

  /// بيسجل موديول جديد في الجداول التلاتة (تعريف + ترخيص + تفعيل)، بس لو
  /// مش مسجل قبل كده - يُستخدم لإضافة موديولات جديدة لنسخ مثبتة بالفعل
  Future<void> _registerModule(
    Database db, {
    required String key,
    required String nameAr,
    required String minTier,
  }) async {
    final existing = await db.query('modules', where: 'module_key = ?', whereArgs: [key]);
    if (existing.isNotEmpty) return;

    await db.insert('modules', {'module_key': key, 'name_ar': nameAr, 'min_tier': minTier});
    await db.insert('licensed_modules', {'module_key': key, 'is_licensed': 1});
    await db.insert('modules_settings', {
      'module_key': key,
      'is_enabled': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _createTables(Database db, int version) async {
    final batch = db.batch();

    // ---------- الفئات ----------
    batch.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // ---------- المنتجات ----------
    batch.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE,
        category_id INTEGER,
        purchase_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        quantity REAL NOT NULL DEFAULT 0,
        reorder_level REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        unit TEXT,
        packaging_type TEXT,
        units_per_package REAL,
        inner_count REAL,
        inner_size REAL,
        image_path TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // ---------- الموردين ----------
    // ملحوظة: التعريف الكامل (بأعمدة company_name/contact_person/notes) موجود تحت
    // مع باقي جداول موديول الموردين، عشان منكررش نفس الجدول مرتين

    // ---------- المستخدمين / الكاشير ----------
    batch.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cashier', -- admin / cashier / accountant / seller / worker / نص حر
        active INTEGER NOT NULL DEFAULT 1,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        employee_id INTEGER,
        FOREIGN KEY (employee_id) REFERENCES employees (id)
      )
    ''');

    // ---------- فواتير البيع ----------
    batch.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'cash', -- cash / card / credit / rep_account
        device_id TEXT,
        customer_name TEXT,
        customer_phone TEXT,
        customer_id INTEGER,
        subtotal_amount REAL NOT NULL DEFAULT 0,
        discount_percent REAL NOT NULL DEFAULT 0,
        discount_amount REAL NOT NULL DEFAULT 0,
        rep_id INTEGER,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (rep_id) REFERENCES reps (id)
      )
    ''');

    // ---------- عناصر فاتورة البيع (صنف من المخزون، أو صنف يدوي/خدمة) ----------
    batch.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
        item_type TEXT NOT NULL DEFAULT 'product',
        manual_name TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // ---------- طلبات التوريد/الشراء الاحترافية ----------
    batch.execute('''
      CREATE TABLE purchase_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER,
        supplier_name TEXT,
        supplier_phone TEXT,
        supplier_email TEXT,
        supplier_address TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        notes TEXT,
        created_by TEXT,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');
    batch.execute('''
      CREATE TABLE purchase_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_order_id INTEGER NOT NULL,
        product_id INTEGER,
        item_name TEXT NOT NULL,
        unit TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // ---------- حركة المخزون (تتبع تلقائي لكل دخول/خروج) ----------
    batch.execute('''
      CREATE TABLE inventory_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL, -- in / out / adjustment
        quantity REAL NOT NULL,
        reference_id INTEGER,
        date TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // ---------- المصروفات ----------
    batch.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        receipt_image_path TEXT
      )
    ''');

    // ---------- سجل النسخ الاحتياطي ----------
    batch.execute('''
      CREATE TABLE backup_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL, -- auto / manual
        date TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    // ---------- الإعدادات العامة (key-value) ----------
    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // ---------- ورديات المستخدمين (وقت الدخول والخروج + ملخص العهدة) ----------
    batch.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        login_time TEXT NOT NULL,
        logout_time TEXT,
        invoice_count INTEGER,
        cash_total REAL,
        card_total REAL,
        total_amount REAL,
        confirmed_by INTEGER,
        confirmed_at TEXT,
        received_amount REAL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // ---------- سجل فتح/قفل التطبيق (معلوماتي بس) ----------
    batch.execute('''
      CREATE TABLE app_open_close_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER,
        user_id INTEGER,
        event TEXT NOT NULL,
        at TEXT NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // ---------- نقاط استلام نقدية الخزنة (المدير/المحاسب) ----------
    batch.execute('''
      CREATE TABLE cash_checkpoints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        by_user_id INTEGER NOT NULL,
        expected_amount REAL NOT NULL DEFAULT 0,
        actual_amount REAL NOT NULL DEFAULT 0,
        at TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (by_user_id) REFERENCES users (id)
      )
    ''');

    // ---------- إقفال اليومية (صورة ثابتة لأرقام كل يوم) ----------
    batch.execute('''
      CREATE TABLE daily_closings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        closing_date TEXT NOT NULL UNIQUE,
        invoice_count INTEGER NOT NULL DEFAULT 0,
        total_revenue REAL NOT NULL DEFAULT 0,
        total_profit REAL NOT NULL DEFAULT 0,
        total_expenses REAL NOT NULL DEFAULT 0,
        cash_total REAL NOT NULL DEFAULT 0,
        card_total REAL NOT NULL DEFAULT 0,
        closed_by INTEGER,
        closed_at TEXT NOT NULL
      )
    ''');

    // ---------- الموردين ----------
    batch.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        logo_path TEXT,
        balance REAL NOT NULL DEFAULT 0
      )
    ''');

    // ---------- أشخاص التواصل عند المورد (أكتر من شخص لكل مورد) ----------
    batch.execute('''
      CREATE TABLE supplier_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        role TEXT,
        phone TEXT,
        email TEXT,
        notes TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // ---------- دفعات التوريد (كل مرة توريد = سطر منفصل) ----------
    batch.execute('''
      CREATE TABLE supply_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        supplier_id INTEGER,
        quantity_received REAL NOT NULL,
        remaining_quantity REAL NOT NULL,
        supply_date TEXT NOT NULL,
        expiry_date TEXT,
        received_by TEXT,
        notes TEXT,
        invoice_image_path TEXT,
        receipt_image_path TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // ---------- مستندات مرنة غير محدودة للمورد (عقود/فواتير/إلخ) ----------
    batch.execute('''
      CREATE TABLE supplier_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        doc_type TEXT NOT NULL DEFAULT 'other',
        title TEXT,
        file_path TEXT NOT NULL,
        uploaded_at TEXT NOT NULL,
        expiry_date TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // ---------- كشف حساب المورد: مديونية (فاتورة/توريد بالأجل) أو دفعة ----------
    batch.execute('''
      CREATE TABLE supplier_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        recorded_by TEXT,
        contract_id INTEGER,
        date TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // ---------- عقود التوريد (اختياري لكل مورد) ----------
    batch.execute('''
      CREATE TABLE supplier_contracts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        start_date TEXT,
        end_date TEXT,
        duration_label TEXT,
        quote_file_path TEXT,
        contract_file_path TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // ---------- أصناف عقد التوريد (مربوطة بالمنتجات المسجّلة، أو صنف يدوي) ----------
    batch.execute('''
      CREATE TABLE supplier_contract_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_id INTEGER NOT NULL,
        product_id INTEGER,
        item_name TEXT NOT NULL,
        category_name TEXT,
        unit TEXT,
        quantity REAL NOT NULL DEFAULT 0,
        unit_price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (contract_id) REFERENCES supplier_contracts (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // ---------- أقساط/دفعات عقد التوريد ----------
    batch.execute('''
      CREATE TABLE supplier_contract_installments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_id INTEGER NOT NULL,
        due_date TEXT,
        amount_due REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        paid_date TEXT,
        notes TEXT,
        FOREIGN KEY (contract_id) REFERENCES supplier_contracts (id)
      )
    ''');

    // ---------- العملاء (CRM) ----------
    batch.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        notes TEXT,
        balance REAL NOT NULL DEFAULT 0,
        loyalty_points INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // ---------- حركة نقاط ولاء العملاء (كسب/استبدال) ----------
    batch.execute('''
      CREATE TABLE customer_loyalty_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        points INTEGER NOT NULL,
        reason TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // ---------- تحصيلات من العملاء (سداد كل أو جزء من الرصيد الآجل) ----------
    batch.execute('''
      CREATE TABLE customer_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        received_by TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // ---------- المرتجعات (عملاء وموردين في جدول واحد، مميّزين بـ type) ----------
    batch.execute('''
      CREATE TABLE returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL, -- 'customer' or 'supplier'
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL,
        reference_sale_id INTEGER,
        supplier_id INTEGER,
        batch_id INTEGER,
        reason TEXT,
        date TEXT NOT NULL,
        processed_by TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // ---------- المناديب ----------
    batch.execute('''
      CREATE TABLE reps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        national_id TEXT,
        address TEXT,
        photo_path TEXT,
        notes TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // ---------- مستندات مرنة غير محدودة للمندوب (بطاقة/عنوان/شهادة/عقد/إضافي) ----------
    batch.execute('''
      CREATE TABLE rep_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rep_id INTEGER NOT NULL,
        doc_type TEXT NOT NULL DEFAULT 'other',
        title TEXT,
        file_path TEXT NOT NULL,
        uploaded_at TEXT NOT NULL,
        expiry_date TEXT,
        FOREIGN KEY (rep_id) REFERENCES reps (id)
      )
    ''');

    // ---------- سجل حركة عهدة المندوب ----------
    batch.execute('''
      CREATE TABLE rep_custody (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rep_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_id INTEGER,
        notes TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (rep_id) REFERENCES reps (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // ---------- فواتير البيع الخارجي للمناديب ----------
    batch.execute('''
      CREATE TABLE rep_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rep_id INTEGER NOT NULL,
        customer_id INTEGER,
        customer_name TEXT,
        customer_phone TEXT,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        total_amount REAL NOT NULL DEFAULT 0,
        notes TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (rep_id) REFERENCES reps (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');
    batch.execute('''
      CREATE TABLE rep_sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rep_sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        FOREIGN KEY (rep_sale_id) REFERENCES rep_sales (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // ---------- طلبات التوصيل ----------
    batch.execute('''
      CREATE TABLE rep_deliveries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rep_id INTEGER NOT NULL,
        sale_id INTEGER,
        customer_name TEXT,
        customer_phone TEXT,
        address TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        notes TEXT,
        assigned_at TEXT NOT NULL,
        delivered_at TEXT,
        FOREIGN KEY (rep_id) REFERENCES reps (id),
        FOREIGN KEY (sale_id) REFERENCES sales (id)
      )
    ''');

    // ---------- تحصيلات المناديب من العملاء ----------
    batch.execute('''
      CREATE TABLE rep_collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rep_id INTEGER NOT NULL,
        customer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (rep_id) REFERENCES reps (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // ---------- تسوية دورية لعهدة المندوب ----------
    batch.execute('''
      CREATE TABLE rep_settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rep_id INTEGER NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        notes TEXT,
        settled_by TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (rep_id) REFERENCES reps (id)
      )
    ''');

    // ---------- الموظفين ----------
    batch.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        national_id TEXT,
        address TEXT,
        position TEXT,
        qualification TEXT,
        salary_type TEXT NOT NULL DEFAULT 'monthly',
        base_salary REAL NOT NULL DEFAULT 0,
        hire_date TEXT,
        photo_path TEXT,
        national_id_image_path TEXT,
        qualification_doc_path TEXT,
        address_proof_path TEXT,
        contract_doc_path TEXT,
        notes TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // ---------- مستندات إضافية للموظف ----------
    batch.execute('''
      CREATE TABLE employee_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        title TEXT,
        file_path TEXT NOT NULL,
        uploaded_at TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES employees (id)
      )
    ''');

    // ---------- حضور وانصراف الموظفين ----------
    batch.execute('''
      CREATE TABLE employee_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        check_in TEXT,
        check_out TEXT,
        status TEXT NOT NULL DEFAULT 'present',
        notes TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (id)
      )
    ''');

    // ---------- مرتبات ويوميات الموظفين ----------
    batch.execute('''
      CREATE TABLE employee_payroll (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        period_label TEXT NOT NULL,
        base_amount REAL NOT NULL DEFAULT 0,
        bonuses REAL NOT NULL DEFAULT 0,
        deductions REAL NOT NULL DEFAULT 0,
        net_amount REAL NOT NULL DEFAULT 0,
        notes TEXT,
        paid_by TEXT,
        paid_at TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES employees (id)
      )
    ''');

    // ---------- الأجهزة المتصلة ----------
    batch.execute('''
      CREATE TABLE connected_devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'printer',
        connection_type TEXT NOT NULL DEFAULT 'bluetooth',
        address TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'unknown',
        last_checked_at TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // ---------- صلاحيات كل مستخدم لكل موديول ----------
    batch.execute('''
      CREATE TABLE user_permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        module_key TEXT NOT NULL,
        allowed INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES users (id),
        UNIQUE(user_id, module_key)
      )
    ''');

    // ---------- العروض التسويقية (تتشارك على واتساب/سوشيال ميديا) ----------
    batch.execute('''
      CREATE TABLE marketing_offers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        image_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // ---------- نظام الموديولات: تعريف كل موديول موجود بالنظام ----------
    batch.execute('''
      CREATE TABLE modules (
        module_key TEXT PRIMARY KEY,
        name_ar TEXT NOT NULL,
        min_tier TEXT NOT NULL DEFAULT 'basic'
      )
    ''');

    // ---------- الموديولات المرخّصة لهذا العميل (حسب مفتاح التفعيل) ----------
    batch.execute('''
      CREATE TABLE licensed_modules (
        module_key TEXT PRIMARY KEY,
        is_licensed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (module_key) REFERENCES modules (module_key)
      )
    ''');

    // ---------- تفعيل/تعطيل تشغيلي بواسطة الأدمن ----------
    batch.execute('''
      CREATE TABLE modules_settings (
        module_key TEXT PRIMARY KEY,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT,
        FOREIGN KEY (module_key) REFERENCES modules (module_key)
      )
    ''');

    await batch.commit(noResult: true);

    // تسجيل الموديولات الأساسية الثلاثة كبيانات أولية
    await _seedInitialModules(db);
    await _seedDefaultAdmin(db);
  }

  /// حساب أدمن افتراضي أول مرة - المستخدم لازم يغيّر كلمة السر بعد أول دخول
  Future<void> _seedDefaultAdmin(Database db) async {
    final existing = await db.query('users', where: "username = ?", whereArgs: ['admin']);
    if (existing.isNotEmpty) return;

    // كلمة السر الافتراضية: admin123 (مشفّرة بـ SHA-256)
    const defaultPasswordHash =
        '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9';

    await db.insert('users', {
      'name': 'المدير',
      'username': 'admin',
      'password_hash': defaultPasswordHash,
      'role': 'admin',
      'active': 1,
    });
  }

  Future<void> _seedInitialModules(Database db) async {
    final now = DateTime.now().toIso8601String();
    final initialModules = [
      {'module_key': 'inventory', 'name_ar': 'المخزون', 'min_tier': 'basic'},
      {'module_key': 'sales', 'name_ar': 'المبيعات', 'min_tier': 'basic'},
      {'module_key': 'accounting', 'name_ar': 'المحاسبة', 'min_tier': 'pro'},
      {'module_key': 'customers', 'name_ar': 'العملاء', 'min_tier': 'pro'},
      {'module_key': 'returns', 'name_ar': 'المرتجعات', 'min_tier': 'pro'},
      {'module_key': 'expiry_alerts', 'name_ar': 'تنبيهات الصلاحية', 'min_tier': 'basic'},
      {'module_key': 'suppliers', 'name_ar': 'الموردين', 'min_tier': 'basic'},
      {'module_key': 'reps', 'name_ar': 'المناديب والشحن', 'min_tier': 'pro'},
      {'module_key': 'hr', 'name_ar': 'الموظفين', 'min_tier': 'pro'},
      {'module_key': 'marketing', 'name_ar': 'العروض التسويقية', 'min_tier': 'pro'},
    ];

    for (final module in initialModules) {
      await db.insert('modules', module);
      // بشكل افتراضي في مرحلة التطوير: كل حاجة مرخّصة ومفعّلة
      // في الإنتاج الفعلي، دي هتتحدد وقت تفعيل كود الترخيص
      await db.insert('licensed_modules', {
        'module_key': module['module_key'],
        'is_licensed': 1,
      });
      await db.insert('modules_settings', {
        'module_key': module['module_key'],
        'is_enabled': 1,
        'updated_at': now,
      });
    }
  }
}
