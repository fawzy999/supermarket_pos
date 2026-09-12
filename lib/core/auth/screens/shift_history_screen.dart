import 'package:flutter/material.dart';
import '../repository/shift_repository.dart';
import 'shift_detail_screen.dart';

class ShiftHistoryScreen extends StatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen> {
  final _repository = ShiftRepository();
  List<Map<String, dynamic>> _shifts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shifts = await _repository.getAllShifts();
    setState(() {
      _shifts = shifts;
      _loading = false;
    });
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return 'لسه شغال';
    return isoString.substring(0, 16).replaceFirst('T', '  ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الورديات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shifts.isEmpty
              ? const Center(child: Text('لا توجد ورديات مسجلة'))
              : ListView.builder(
                  itemCount: _shifts.length,
                  itemBuilder: (context, index) {
                    final shift = _shifts[index];
                    final isOpen = shift['logout_time'] == null;
                    final isConfirmed = shift['confirmed_by'] != null;

                    Widget trailingWidget;
                    if (isOpen) {
                      trailingWidget = const SizedBox.shrink();
                    } else if (isConfirmed) {
                      trailingWidget = const Icon(Icons.verified_outlined, color: Colors.green);
                    } else {
                      trailingWidget = const Icon(Icons.warning_amber_rounded, color: Colors.orange);
                    }

                    return ListTile(
                      leading: Icon(
                        isOpen ? Icons.circle : Icons.check_circle_outline,
                        color: isOpen ? Colors.green : Colors.grey,
                      ),
                      title: Text(shift['user_name'] as String),
                      subtitle: Text(
                        'دخول: ${_formatTime(shift['login_time'] as String)}\n'
                        'خروج: ${_formatTime(shift['logout_time'] as String?)}'
                        '${shift['total_amount'] != null ? '\nالإجمالي: ${(shift['total_amount'] as num).toStringAsFixed(2)} ج' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: trailingWidget,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShiftDetailScreen(
                              shiftId: shift['id'] as int,
                              userName: shift['user_name'] as String,
                            ),
                          ),
                        ).then((_) => _load());
                      },
                    );
                  },
                ),
    );
  }
}
