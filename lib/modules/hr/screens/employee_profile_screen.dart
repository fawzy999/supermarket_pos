import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/auth/session/current_session.dart';
import '../models/employee.dart';
import '../repository/employee_repository.dart';
import 'employee_attendance_screen.dart';
import 'employee_documents_screen.dart';
import 'employee_form_screen.dart';
import 'employee_payroll_screen.dart';

/// بروفايل الموظف: بياناته ومستنداته الأساسية، وبوابة الدخول
/// لحضوره وانصرافه ومستنداته الإضافية ومرتبه/يوميته (المرتبات
/// متاحة للأدمن فقط لحساسية بيانات الأجور).
class EmployeeProfileScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeProfileScreen({super.key, required this.employee});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final _repository = EmployeeRepository();
  late Employee _employee;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final refreshed = await _repository.getEmployeeById(_employee.id!);
    setState(() {
      _employee = refreshed ?? _employee;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeFormScreen(employee: _employee)));
    _load();
  }

  Future<void> _openAttendance() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeAttendanceScreen(employee: _employee)));
  }

  Future<void> _openDocuments() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDocumentsScreen(employee: _employee)));
  }

  Future<void> _openPayroll() async {
    if (!CurrentSession.instance.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المرتبات والأجور متاحة للأدمن فقط')),
      );
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeePayrollScreen(employee: _employee)));
  }

  Widget _docThumb(String label, String? path) {
    final exists = path != null && File(path).existsSync();
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            image: exists ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover) : null,
          ),
          child: !exists ? const Icon(Icons.insert_drive_file_outlined, color: Colors.grey) : null,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 72,
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_employee.name),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: (_employee.photoPath != null && File(_employee.photoPath!).existsSync())
                              ? FileImage(File(_employee.photoPath!)) as ImageProvider
                              : null,
                          child: (_employee.photoPath == null || !File(_employee.photoPath!).existsSync())
                              ? const Icon(Icons.person_outline, size: 32)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(_employee.name,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                  if (!_employee.active)
                                    const Chip(label: Text('غير نشط'), visualDensity: VisualDensity.compact),
                                ],
                              ),
                              if ((_employee.position ?? '').isNotEmpty) Text('الوظيفة: ${_employee.position}'),
                              if ((_employee.qualification ?? '').isNotEmpty)
                                Text('المؤهل: ${_employee.qualification}'),
                              if ((_employee.phone ?? '').isNotEmpty) Text('التليفون: ${_employee.phone}'),
                              if ((_employee.nationalId ?? '').isNotEmpty)
                                Text('الرقم القومي: ${_employee.nationalId}'),
                              if ((_employee.address ?? '').isNotEmpty) Text('العنوان: ${_employee.address}'),
                              Text(
                                _employee.isMonthly
                                    ? 'مرتب شهري: ${_employee.baseSalary.toStringAsFixed(2)} ج'
                                    : 'يومية: ${_employee.baseSalary.toStringAsFixed(2)} ج/يوم',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _docThumb('بطاقة الرقم القومي', _employee.nationalIdImagePath),
                        const SizedBox(width: 12),
                        _docThumb('مستند الشهادة', _employee.qualificationDocPath),
                        const SizedBox(width: 12),
                        _docThumb('إثبات العنوان', _employee.addressProofPath),
                        const SizedBox(width: 12),
                        _docThumb('عقد العمل', _employee.contractDocPath),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.4,
                    children: [
                      _actionCard('الحضور والانصراف', Icons.fact_check_outlined, _openAttendance),
                      _actionCard('مستندات إضافية', Icons.folder_open_outlined, _openDocuments),
                      _actionCard(
                        _employee.isMonthly ? 'المرتب' : 'اليومية',
                        Icons.payments_outlined,
                        _openPayroll,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _actionCard(String label, IconData icon, VoidCallback onTap) => Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      );
}
