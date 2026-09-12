class AppUser {
  final int? id;
  final String name;
  final String username;
  final String role; // admin / cashier / accountant / seller / worker / نص حر
  final bool active;
  final bool biometricEnabled;
  final int? employeeId; // لو الحساب ده مربوط بسجل موظف في موديول الـ HR

  AppUser({
    this.id,
    required this.name,
    required this.username,
    required this.role,
    this.active = true,
    this.biometricEnabled = false,
    this.employeeId,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as int?,
        name: map['name'] as String,
        username: map['username'] as String,
        role: map['role'] as String,
        active: (map['active'] as int) == 1,
        biometricEnabled: (map['biometric_enabled'] as int?) == 1,
        employeeId: map['employee_id'] as int?,
      );
}
