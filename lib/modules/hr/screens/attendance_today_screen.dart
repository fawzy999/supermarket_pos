import 'package:flutter/material.dart';
import '../repository/employee_repository.dart';

/// شاشة سريعة يومية: تسجيل حضور/انصراف كل الموظفين النشطين بضغطة واحدة،
/// أو تسجيل غياب/إجازة يدوي لمن لا يستخدم بصمة حضور.
class AttendanceTodayScreen extends StatefulWidget {
  const AttendanceTodayScreen({super.key});

  @override
  State<AttendanceTodayScreen> createState() => _AttendanceTodayScreenState();
}

class _AttendanceTodayScreenState extends State<AttendanceTodayScreen> {
  final _repository = EmployeeRepository();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _repository.getTodayAttendance();
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _checkIn(int employeeId) async {
    await _repository.checkIn(employeeId);
    _load();
  }

  Future<void> _checkOut(int employeeId) async {
    await _repository.checkOut(employeeId);
    _load();
  }

  Future<void> _markStatus(int employeeId, String status) async {
    await _repository.markAttendance(employeeId: employeeId, status: status);
    _load();
  }

  String _statusLabel(String? status) => switch (status) {
        'present' => 'حاضر',
        'absent' => 'غايب',
        'leave' => 'إجازة',
        'late' => 'متأخر',
        _ => 'لسه مسجّلش',
      };

  Color _statusColor(String? status) => switch (status) {
        'present' => Colors.green,
        'absent' => Colors.red,
        'leave' => Colors.blue,
        'late' => Colors.orange,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateLabel = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: Text('حضور وانصراف - $dateLabel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('لا يوجد موظفين نشطين'))
              : ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    final employeeId = row['employee_id'] as int;
                    final status = row['status'] as String?;
                    final checkIn = row['check_in'] as String?;
                    final checkOut = row['check_out'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row['employee_name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                Chip(
                                  label: Text(_statusLabel(status)),
                                  backgroundColor: _statusColor(status).withOpacity(0.15),
                                  labelStyle: TextStyle(color: _statusColor(status)),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            if (checkIn != null)
                              Text('حضر: ${checkIn.substring(11, 16)}'
                                  '${checkOut != null ? '  •  انصرف: ${checkOut.substring(11, 16)}' : ''}'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: [
                                OutlinedButton(
                                  onPressed: checkIn == null ? () => _checkIn(employeeId) : null,
                                  child: const Text('تسجيل حضور'),
                                ),
                                OutlinedButton(
                                  onPressed: (checkIn != null && checkOut == null) ? () => _checkOut(employeeId) : null,
                                  child: const Text('تسجيل انصراف'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _markStatus(employeeId, 'absent'),
                                  child: const Text('غياب'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _markStatus(employeeId, 'leave'),
                                  child: const Text('إجازة'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
