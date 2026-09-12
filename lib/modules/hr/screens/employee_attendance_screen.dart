import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../repository/employee_repository.dart';

/// سجل حضور وانصراف موظف معين، مع ملخص شهري وأزرار تسجيل سريعة.
class EmployeeAttendanceScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeAttendanceScreen({super.key, required this.employee});

  @override
  State<EmployeeAttendanceScreen> createState() => _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  final _repository = EmployeeRepository();
  List<Map<String, dynamic>> _history = [];
  Map<String, int> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final history = await _repository.getAttendanceHistory(widget.employee.id!);
    final monthStart = DateTime.now().toIso8601String().substring(0, 8) + '01';
    final summary = await _repository.getAttendanceSummary(widget.employee.id!, sinceDate: monthStart);
    setState(() {
      _history = history;
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _quickAction() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('تسجيل سريع'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'checkin'), child: const Text('تسجيل حضور اليوم')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'checkout'), child: const Text('تسجيل انصراف اليوم')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'absent'), child: const Text('غياب اليوم')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'leave'), child: const Text('إجازة اليوم')),
        ],
      ),
    );
    if (action == null) return;

    switch (action) {
      case 'checkin':
        await _repository.checkIn(widget.employee.id!);
        break;
      case 'checkout':
        await _repository.checkOut(widget.employee.id!);
        break;
      case 'absent':
        await _repository.markAttendance(employeeId: widget.employee.id!, status: 'absent');
        break;
      case 'leave':
        await _repository.markAttendance(employeeId: widget.employee.id!, status: 'leave');
        break;
    }
    _load();
  }

  String _statusLabel(String status) => switch (status) {
        'present' => 'حاضر',
        'absent' => 'غايب',
        'leave' => 'إجازة',
        'late' => 'متأخر',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('حضور ${widget.employee.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _quickAction,
        icon: const Icon(Icons.add),
        label: const Text('تسجيل سريع'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      Chip(label: Text('حاضر هذا الشهر: ${_summary['present'] ?? 0}')),
                      Chip(label: Text('غياب: ${_summary['absent'] ?? 0}')),
                      Chip(label: Text('إجازة: ${_summary['leave'] ?? 0}')),
                      Chip(label: Text('متأخر: ${_summary['late'] ?? 0}')),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('سجل الحضور', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_history.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('لا يوجد سجل حضور بعد'))
                else
                  ..._history.map((row) {
                    final checkIn = row['check_in'] as String?;
                    final checkOut = row['check_out'] as String?;
                    return ListTile(
                      leading: const Icon(Icons.event_note_outlined),
                      title: Text(row['date'] as String),
                      subtitle: Text(
                        '${_statusLabel(row['status'] as String)}'
                        '${checkIn != null ? '  •  حضر: ${checkIn.substring(11, 16)}' : ''}'
                        '${checkOut != null ? '  •  انصرف: ${checkOut.substring(11, 16)}' : ''}',
                      ),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
