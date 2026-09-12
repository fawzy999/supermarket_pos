import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../repository/auth_repository.dart';
import 'user_form_screen.dart';

/// نفس تسميات الصلاحيات المعروضة في فورم إضافة المستخدم - لعرض تسمية
/// عربية للمسميات المعروفة، وأي مسمى حر (مكتوب بنفسه) بيُعرض كما هو
const Map<String, String> _knownRoleLabels = {
  'admin': 'أدمن',
  'cashier': 'كاشير',
  'accountant': 'محاسب',
  'seller': 'بائع',
  'worker': 'عامل',
};

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _repository = AuthRepository();
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await _repository.getAllUsers();
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _addUser() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const UserFormScreen()),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدمين')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('مستخدم جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final roleLabel = _knownRoleLabels[user.role] ?? user.role;
                return ListTile(
                  leading: Icon(user.isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline),
                  title: Text(user.name),
                  subtitle: Text(
                    '${user.username}  •  $roleLabel'
                    '${user.biometricEnabled ? '  •  بصمة مفعّلة' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.fingerprint,
                          color: user.biometricEnabled ? Colors.teal : Colors.grey,
                        ),
                        tooltip: user.biometricEnabled ? 'تعطيل الدخول بالبصمة' : 'تفعيل الدخول بالبصمة',
                        onPressed: () async {
                          await _repository.setBiometricEnabled(user.id!, !user.biometricEnabled);
                          _load();
                        },
                      ),
                      Switch(
                        value: user.active,
                        onChanged: (value) async {
                          await _repository.setUserActive(user.id!, value);
                          _load();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
