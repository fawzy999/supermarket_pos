import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/app_database.dart';
import '../models/app_user.dart';

class AuthRepository {
  final _db = AppDatabase.instance;

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// بيتحقق من اليوزر وكلمة السر، ويرجع المستخدم لو صح، أو null لو غلط
  Future<AppUser?> login({required String username, required String password}) async {
    final hash = _hashPassword(password);
    final rows = await _db.database.query(
      'users',
      where: 'username = ? AND password_hash = ? AND active = 1',
      whereArgs: [username, hash],
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> getAllUsers() async {
    final rows = await _db.database.query('users', orderBy: 'name');
    return rows.map((r) => AppUser.fromMap(r)).toList();
  }

  Future<int> addUser({
    required String name,
    required String username,
    required String password,
    required String role,
    int? employeeId,
  }) async {
    return _db.database.insert('users', {
      'name': name,
      'username': username,
      'password_hash': _hashPassword(password),
      'role': role,
      'active': 1,
      'employee_id': employeeId,
    });
  }

  /// كل الموظفين اللي عندهم حساب مستخدم مرتبط بالفعل - عشان مانكررش
  /// حساب لموظف واحد أكتر من مرة عند إنشاء مستخدم جديد
  Future<Set<int>> getLinkedEmployeeIds() async {
    final rows = await _db.database.query(
      'users',
      columns: ['employee_id'],
      where: 'employee_id IS NOT NULL',
    );
    return rows.map((r) => r['employee_id'] as int).toSet();
  }

  Future<void> setUserActive(int userId, bool active) async {
    await _db.database.update(
      'users',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> changePassword(int userId, String newPassword) async {
    await _db.database.update(
      'users',
      {'password_hash': _hashPassword(newPassword)},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// بيتأكد إن اسم اليوزر متاح قبل الإضافة
  Future<bool> isUsernameTaken(String username) async {
    final rows = await _db.database.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return rows.isNotEmpty;
  }

  Future<AppUser?> getUserById(int userId) async {
    final rows = await _db.database.query('users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  /// المستخدمين المفعّل عندهم الدخول بالبصمة على الجهاز ده
  Future<List<AppUser>> getBiometricEnabledUsers() async {
    final rows = await _db.database.query(
      'users',
      where: 'biometric_enabled = 1 AND active = 1',
      orderBy: 'name',
    );
    return rows.map((r) => AppUser.fromMap(r)).toList();
  }

  Future<void> setBiometricEnabled(int userId, bool enabled) async {
    await _db.database.update(
      'users',
      {'biometric_enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
