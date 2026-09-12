import 'package:flutter/material.dart';
import '../../../core/auth/session/current_session.dart';
import '../models/employee.dart';
import '../repository/employee_repository.dart';

/// المرتبات واليوميات: حساب المستحق للموظف (شهري ثابت، أو يومية على
/// حسب أيام الحضور)، مع إمكانية إضافة مكافآت أو خصومات وتسجيل الصرف،
/// وسجل كل عمليات الصرف السابقة.
class EmployeePayrollScreen extends StatefulWidget {
  final Employee employee;

  const EmployeePayrollScreen({super.key, required this.employee});

  @override
  State<EmployeePayrollScreen> createState() => _EmployeePayrollScreenState();
}

class _EmployeePayrollScreenState extends State<EmployeePayrollScreen> {
  final _repository = EmployeeRepository();
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final history = await _repository.getPayrollHistory(widget.employee.id!);
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<void> _recordPayment() async {
    final monthStart = DateTime.now().toIso8601String().substring(0, 8) + '01';
    final summary = await _repository.getAttendanceSummary(widget.employee.id!, sinceDate: monthStart);
    final presentDays = summary['present'] ?? 0;

    final suggestedBase = widget.employee.isMonthly
        ? widget.employee.baseSalary
        : widget.employee.baseSalary * presentDays;

    final now = DateTime.now();
    final periodController = TextEditingController(text: '${now.year}-${now.month.toString().padLeft(2, '0')}');
    final baseController = TextEditingController(text: suggestedBase.toStringAsFixed(2));
    final bonusesController = TextEditingController(text: '0');
    final deductionsController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل صرف'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.employee.isMonthly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('أيام الحضور هذا الشهر: $presentDays يوم × ${widget.employee.baseSalary.toStringAsFixed(2)} ج'),
                  ),
                TextFormField(
                  controller: periodController,
                  decoration: const InputDecoration(labelText: 'الفترة (مثال: 2026-09)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: baseController,
                  decoration: const InputDecoration(labelText: 'الأساسي'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final parsed = double.tryParse(v ?? '');
                    if (parsed == null || parsed < 0) return 'قيمة غير صحيحة';
                    return null;
                  },
                ),
                TextFormField(
                  controller: bonusesController,
                  decoration: const InputDecoration(labelText: 'مكافآت / حوافز (اختياري)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextFormField(
                  controller: deductionsController,
                  decoration: const InputDecoration(labelText: 'خصومات / سلف (اختياري)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('تسجيل الصرف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await _repository.recordPayroll(
        employeeId: widget.employee.id!,
        periodLabel: periodController.text.trim(),
        baseAmount: double.parse(baseController.text),
        bonuses: double.tryParse(bonusesController.text) ?? 0,
        deductions: double.tryParse(deductionsController.text) ?? 0,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        paidBy: CurrentSession.instance.user?.name,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.employee.isMonthly ? 'مرتب' : 'يومية'} ${widget.employee.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _recordPayment,
        icon: const Icon(Icons.payments_outlined),
        label: Text(_saving ? 'جاري الحفظ...' : 'تسجيل صرف'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.employee.isMonthly
                        ? 'المرتب الأساسي: ${widget.employee.baseSalary.toStringAsFixed(2)} ج شهريًا'
                        : 'اليومية: ${widget.employee.baseSalary.toStringAsFixed(2)} ج لليوم',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('سجل الصرف', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_history.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد عمليات صرف مسجلة بعد'))
                else
                  ..._history.map((row) => ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text('${row['period_label']}  •  ${(row['net_amount'] as num).toStringAsFixed(2)} ج'),
                        subtitle: Text(
                          'أساسي: ${(row['base_amount'] as num).toStringAsFixed(2)}'
                          '  +مكافآت: ${(row['bonuses'] as num).toStringAsFixed(2)}'
                          '  -خصومات: ${(row['deductions'] as num).toStringAsFixed(2)}\n'
                          '${(row['paid_at'] as String).substring(0, 16).replaceFirst('T', ' ')}'
                          '${row['paid_by'] != null ? '  •  صرفها: ${row['paid_by']}' : ''}',
                        ),
                        isThreeLine: true,
                      )),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
