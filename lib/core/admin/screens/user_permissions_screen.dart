import 'package:flutter/material.dart';
import '../../auth/models/app_user.dart';
import '../../auth/repository/auth_repository.dart';
import '../../modules_registry/module_registry.dart';
import '../../modules_registry/module_repository.dart';
import '../repository/permission_repository.dart';

/// تحديد أي موديولات يقدر كل كاشير/موظف يشوفها ويستخدمها - فوق تفعيل
/// الموديول نفسه. الأدمن دايمًا شايف كل حاجة، والتحكم ده للمستخدمين
/// التانيين بس (كاشير أو أي حساب مش أدمن).
class UserPermissionsScreen extends StatefulWidget {
  const UserPermissionsScreen({super.key});

  @override
  State<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> {
  final _authRepository = AuthRepository();
  final _moduleRepository = ModuleRepository();
  final _permissionRepository = PermissionRepository();

  List<AppUser> _users = [];
  AppUser? _selectedUser;
  Map<String, Map<String, bool>> _moduleStatus = {};
  Map<String, bool> _userPermissions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await _authRepository.getAllUsers();
    final moduleStatus = await _moduleRepository.getAllModulesStatus();
    setState(() {
      _users = users.where((u) => !u.isAdmin).toList();
      _moduleStatus = moduleStatus;
      _loading = false;
    });
  }

  Future<void> _selectUser(AppUser user) async {
    setState(() => _selectedUser = user);
    final permissions = await _permissionRepository.getPermissionsForUser(user.id!);
    setState(() => _userPermissions = permissions);
  }

  Future<void> _togglePermission(String moduleKey, bool allowed) async {
    if (_selectedUser == null) return;
    await _permissionRepository.setPermission(userId: _selectedUser!.id!, moduleKey: moduleKey, allowed: allowed);
    setState(() => _userPermissions[moduleKey] = allowed);
  }

  @override
  Widget build(BuildContext context) {
    final availableModules = ModuleRegistry.all.where((m) {
      final status = _moduleStatus[m.key];
      return (status?['is_licensed'] ?? false) && (status?['is_enabled'] ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('صلاحيات المستخدمين')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('لا يوجد مستخدمين غير الأدمن حاليًا'))
              : Row(
                  children: [
                    SizedBox(
                      width: 160,
                      child: ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final selected = _selectedUser?.id == user.id;
                          return ListTile(
                            selected: selected,
                            title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: const Text('كاشير'),
                            onTap: () => _selectUser(user),
                          );
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _selectedUser == null
                          ? const Center(child: Text('اختر مستخدم من القائمة'))
                          : ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'صلاحيات: ${_selectedUser!.name}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                SwitchListTile(
                                  secondary: const Icon(Icons.point_of_sale_outlined),
                                  title: const Text('صلاحية استلام نقدية من الخزنة'),
                                  subtitle: const Text(
                                    'يقدر يستلم كاش الدرج ويصفّره (زي المحاسب) - افتراضيًا ممنوعة',
                                  ),
                                  value: _userPermissions[PermissionRepository.permCashPickup] ?? false,
                                  onChanged: (v) => _togglePermission(PermissionRepository.permCashPickup, v),
                                ),
                                const Divider(),
                                ...availableModules.map((module) {
                                  final allowed = _userPermissions[module.key] ?? true;
                                  return SwitchListTile(
                                    secondary: Icon(module.icon),
                                    title: Text(module.nameAr),
                                    value: allowed,
                                    onChanged: (v) => _togglePermission(module.key, v),
                                  );
                                }),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }
}
