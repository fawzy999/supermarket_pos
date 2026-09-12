import 'package:flutter/material.dart';
import '../repository/auth_repository.dart';
import '../../../modules/hr/models/employee.dart';
import '../../../modules/hr/repository/employee_repository.dart';
import '../../../modules/hr/screens/employee_form_screen.dart';

/// خيارات الصلاحية المتاحة عند إضافة مستخدم - لو المستخدم عاوز مسمى
/// تاني غير الموجودين، بيختار "أخرى" ويكتبه بنفسه في حقل نصي بيبقى
/// هو قيمة role المحفوظة مباشرة.
const Map<String, String> _roleOptions = {
  'admin': 'أدمن',
  'cashier': 'كاشير',
  'accountant': 'محاسب',
  'seller': 'بائع',
  'worker': 'عامل',
  'other': 'أخرى (حدد المسمى)',
};

/// شاشة إضافة مستخدم جديد (حساب دخول للتطبيق): إما بربطه بموظف موجود
/// بالفعل في موديول الموظفين (فبتظهر بياناته على طول)، أو بإدخال بيانات
/// موظف/مستخدم جديد بالكامل (بيفتح فورم الموظف العادي نفسه) قبل ما نكمل
/// بيانات الدخول (اليوزر/الباسورد/الصلاحية).
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _authRepository = AuthRepository();
  final _employeeRepository = EmployeeRepository();
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _customRoleController = TextEditingController();

  List<Employee> _employees = [];
  Set<int> _linkedEmployeeIds = {};
  bool _loading = true;
  bool _saving = false;

  bool _linkToEmployee = true;
  Employee? _selectedEmployee;
  String _selectedRole = 'cashier';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final employees = await _employeeRepository.getAllEmployees(activeOnly: true);
    final linkedIds = await _authRepository.getLinkedEmployeeIds();
    setState(() {
      _employees = employees;
      _linkedEmployeeIds = linkedIds;
      _loading = false;
    });
  }

  /// الموظفين المتاحين للربط بس (اللي لسه معملهم حساب دخول)
  List<Employee> get _availableEmployees =>
      _employees.where((e) => !_linkedEmployeeIds.contains(e.id)).toList();

  /// فتح فورم الموظف العادي لإدخال بياناته كاملة (بيانات موظف جديد
  /// بالكامل)، وبعد الحفظ يترشّح تلقائيًا كالموظف المربوط بالمستخدم
  Future<void> _addNewEmployeeInline() async {
    final created = await Navigator.push<Employee>(
      context,
      MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
    );
    if (created == null || !mounted) return;
    setState(() {
      _employees = [..._employees, created];
      _selectedEmployee = created;
      if (_usernameController.text.trim().isEmpty) {
        // اقتراح مبدئي لاسم المستخدم من الاسم - المستخدم يقدر يغيّره
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_linkToEmployee && _selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختار الموظف المطلوب ربطه بالمستخدم، أو أضف موظف جديد بالكامل')),
      );
      return;
    }

    final role = _selectedRole == 'other' ? _customRoleController.text.trim() : _selectedRole;
    if (role.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب المسمى الوظيفي/الصلاحية')),
      );
      return;
    }

    setState(() => _saving = true);

    final taken = await _authRepository.isUsernameTaken(_usernameController.text.trim());
    if (taken) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اسم المستخدم ده مستخدم بالفعل')),
        );
      }
      return;
    }

    await _authRepository.addUser(
      name: _selectedEmployee?.name ?? _usernameController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      role: role,
      employeeId: _selectedEmployee?.id,
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مستخدم جديد')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('بيانات الموظف', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('ربط بموظف موجود')),
                      ButtonSegment(value: false, label: Text('موظف/مستخدم جديد بالكامل')),
                    ],
                    selected: {_linkToEmployee},
                    onSelectionChanged: (s) => setState(() {
                      _linkToEmployee = s.first;
                      _selectedEmployee = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (_linkToEmployee) ...[
                    if (_availableEmployees.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'مفيش موظفين نشطين لسه من غير حساب دخول - تقدر تضيف موظف جديد بالكامل بدل ذلك',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      DropdownButtonFormField<Employee>(
                        initialValue: _selectedEmployee,
                        decoration: const InputDecoration(labelText: 'اختر الموظف'),
                        items: _availableEmployees
                            .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedEmployee = v),
                      ),
                    if (_selectedEmployee != null) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.grey.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الاسم: ${_selectedEmployee!.name}'),
                              if ((_selectedEmployee!.position ?? '').isNotEmpty)
                                Text('الوظيفة: ${_selectedEmployee!.position}'),
                              if ((_selectedEmployee!.phone ?? '').isNotEmpty)
                                Text('التليفون: ${_selectedEmployee!.phone}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _addNewEmployeeInline,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('أو أضف موظف جديد بالكامل من هنا'),
                    ),
                  ] else ...[
                    if (_selectedEmployee == null)
                      FilledButton.icon(
                        onPressed: _addNewEmployeeInline,
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('إدخال بيانات الموظف الكاملة'),
                      )
                    else
                      Card(
                        color: Colors.teal.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.teal),
                              const SizedBox(width: 8),
                              Expanded(child: Text('تم إدخال بيانات: ${_selectedEmployee!.name}')),
                              TextButton(
                                onPressed: _addNewEmployeeInline,
                                child: const Text('تعديل'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const Divider(height: 32),
                  const Text('بيانات الدخول والصلاحية', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'كلمة السر'),
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(labelText: 'الصلاحية / المسمى'),
                    items: _roleOptions.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRole = v ?? 'cashier'),
                  ),
                  if (_selectedRole == 'other') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customRoleController,
                      decoration: const InputDecoration(labelText: 'اكتب المسمى الوظيفي'),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
              ),
            ),
    );
  }
}
