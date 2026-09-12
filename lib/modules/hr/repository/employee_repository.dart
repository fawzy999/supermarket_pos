import '../../../core/database/app_database.dart';
import '../models/employee.dart';

/// المسؤول عن كل عمليات موديول "الموظفين": بياناتهم الكاملة ومستنداتهم،
/// الحضور والانصراف، والمرتبات/اليوميات.
class EmployeeRepository {
  final _db = AppDatabase.instance;

  // ---------------- بيانات الموظف ----------------

  Future<List<Employee>> getAllEmployees({String? searchQuery, bool activeOnly = false}) async {
    final conditions = <String>[];
    final args = <Object>[];
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(name LIKE ? OR phone LIKE ? OR national_id LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
    if (activeOnly) conditions.add('active = 1');

    final rows = await _db.database.query(
      'employees',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: conditions.isEmpty ? null : args,
      orderBy: 'name',
    );
    return rows.map((r) => Employee.fromMap(r)).toList();
  }

  Future<Employee?> getEmployeeById(int id) async {
    final rows = await _db.database.query('employees', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Employee.fromMap(rows.first);
  }

  Future<int> addEmployee(Employee employee) => _db.database.insert('employees', employee.toMap());

  Future<void> updateEmployee(Employee employee) => _db.database.update(
        'employees',
        employee.toMap(),
        where: 'id = ?',
        whereArgs: [employee.id],
      );

  Future<void> setActive(int employeeId, bool active) => _db.database.update(
        'employees',
        {'active': active ? 1 : 0},
        where: 'id = ?',
        whereArgs: [employeeId],
      );

  // ---------------- مستندات إضافية ----------------

  Future<List<Map<String, dynamic>>> getDocumentsForEmployee(int employeeId) async {
    return _db.database.query(
      'employee_documents',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'uploaded_at DESC',
    );
  }

  Future<int> addDocument({required int employeeId, String? title, required String filePath}) {
    return _db.database.insert('employee_documents', {
      'employee_id': employeeId,
      'title': title,
      'file_path': filePath,
      'uploaded_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteDocument(int id) => _db.database.delete('employee_documents', where: 'id = ?', whereArgs: [id]);

  // ---------------- الحضور والانصراف ----------------

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  Future<Map<String, dynamic>?> _todayRow(int employeeId) async {
    final rows = await _db.database.query(
      'employee_attendance',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, _today],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// تسجيل حضور اليوم (لو مسجل بالفعل، مش هيكرره)
  Future<void> checkIn(int employeeId, {String? notes}) async {
    final existing = await _todayRow(employeeId);
    if (existing != null) return;
    await _db.database.insert('employee_attendance', {
      'employee_id': employeeId,
      'date': _today,
      'check_in': DateTime.now().toIso8601String(),
      'status': 'present',
      'notes': notes,
    });
  }

  /// تسجيل انصراف اليوم (لازم يكون سجل حضور موجود الأول)
  Future<void> checkOut(int employeeId) async {
    final existing = await _todayRow(employeeId);
    if (existing == null) return;
    await _db.database.update(
      'employee_attendance',
      {'check_out': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [existing['id']],
    );
  }

  /// تسجيل يدوي لحالة يوم معين (غياب/إجازة) - بيستبدل أي سجل موجود لنفس اليوم
  Future<void> markAttendance({
    required int employeeId,
    required String status, // present / absent / leave / late
    String? date,
    String? notes,
  }) async {
    final targetDate = date ?? _today;
    final rows = await _db.database.query(
      'employee_attendance',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, targetDate],
      limit: 1,
    );
    if (rows.isEmpty) {
      await _db.database.insert('employee_attendance', {
        'employee_id': employeeId,
        'date': targetDate,
        'status': status,
        'notes': notes,
      });
    } else {
      await _db.database.update(
        'employee_attendance',
        {'status': status, if (notes != null) 'notes': notes},
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    }
  }

  /// حالة كل الموظفين النشطين اليوم - لشاشة الحضور اليومية السريعة
  Future<List<Map<String, dynamic>>> getTodayAttendance() async {
    return _db.database.rawQuery('''
      SELECT employees.id as employee_id, employees.name as employee_name,
        employee_attendance.id as attendance_id,
        employee_attendance.check_in, employee_attendance.check_out,
        employee_attendance.status
      FROM employees
      LEFT JOIN employee_attendance
        ON employee_attendance.employee_id = employees.id AND employee_attendance.date = ?
      WHERE employees.active = 1
      ORDER BY employees.name
    ''', [_today]);
  }

  Future<List<Map<String, dynamic>>> getAttendanceHistory(int employeeId, {int limit = 90}) async {
    return _db.database.query(
      'employee_attendance',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  /// ملخص الحضور خلال فترة معينة - أساس حساب اليومية المستحقة
  Future<Map<String, int>> getAttendanceSummary(int employeeId, {required String sinceDate}) async {
    final rows = await _db.database.query(
      'employee_attendance',
      where: 'employee_id = ? AND date >= ?',
      whereArgs: [employeeId, sinceDate],
    );
    final summary = {'present': 0, 'absent': 0, 'leave': 0, 'late': 0};
    for (final row in rows) {
      final status = row['status'] as String;
      summary[status] = (summary[status] ?? 0) + 1;
    }
    return summary;
  }

  // ---------------- المرتبات واليوميات ----------------

  Future<int> recordPayroll({
    required int employeeId,
    required String periodLabel,
    required double baseAmount,
    double bonuses = 0,
    double deductions = 0,
    String? notes,
    String? paidBy,
  }) {
    final net = baseAmount + bonuses - deductions;
    return _db.database.insert('employee_payroll', {
      'employee_id': employeeId,
      'period_label': periodLabel,
      'base_amount': baseAmount,
      'bonuses': bonuses,
      'deductions': deductions,
      'net_amount': net,
      'notes': notes,
      'paid_by': paidBy,
      'paid_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPayrollHistory(int employeeId) async {
    return _db.database.query(
      'employee_payroll',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'paid_at DESC',
    );
  }

  /// إجمالي ما تم صرفه لكل الموظفين هذا الشهر - لملخص سريع
  Future<double> getTotalPayrollThisMonth() async {
    final monthStart = DateTime.now().toIso8601String().substring(0, 7); // YYYY-MM
    final result = await _db.database.rawQuery(
      "SELECT SUM(net_amount) as total FROM employee_payroll WHERE paid_at LIKE ?",
      ['$monthStart%'],
    );
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }
}
