import 'dart:io';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../repository/employee_repository.dart';
import 'attendance_today_screen.dart';
import 'employee_form_screen.dart';
import 'employee_profile_screen.dart';

/// الشاشة الرئيسية لموديول "الموظفين": قائمة الموظفين، إضافة موظف
/// جديد، والدخول السريع لشاشة حضور وانصراف اليوم لكل الموظفين.
class EmployeesHomeScreen extends StatefulWidget {
  const EmployeesHomeScreen({super.key});

  @override
  State<EmployeesHomeScreen> createState() => _EmployeesHomeScreenState();
}

class _EmployeesHomeScreenState extends State<EmployeesHomeScreen> {
  final _repository = EmployeeRepository();
  List<Employee> _employees = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final employees = await _repository.getAllEmployees(searchQuery: _searchQuery);
    setState(() {
      _employees = employees;
      _loading = false;
    });
  }

  Future<void> _addEmployee() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeFormScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموظفين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'حضور وانصراف اليوم',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendanceTodayScreen()),
              );
              _load();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو التليفون أو الرقم القومي',
                prefixIcon: Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _load();
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEmployee,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('موظف جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? const Center(child: Text('لا يوجد موظفين مسجلين حتى الآن'))
              : ListView.builder(
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (employee.photoPath != null && File(employee.photoPath!).existsSync())
                            ? FileImage(File(employee.photoPath!)) as ImageProvider
                            : null,
                        child: (employee.photoPath == null || !File(employee.photoPath!).existsSync())
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      title: Text(employee.name),
                      subtitle: Text([
                        if ((employee.position ?? '').isNotEmpty) employee.position!,
                        employee.phone ?? '',
                      ].where((s) => s.isNotEmpty).join('  •  ')),
                      trailing: !employee.active
                          ? const Chip(label: Text('غير نشط'), visualDensity: VisualDensity.compact)
                          : null,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EmployeeProfileScreen(employee: employee)),
                        );
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}
