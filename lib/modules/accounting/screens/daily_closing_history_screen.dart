import 'package:flutter/material.dart';
import '../repository/daily_closing_repository.dart';
import '../../../core/auth/session/current_session.dart';

class DailyClosingHistoryScreen extends StatefulWidget {
  const DailyClosingHistoryScreen({super.key});

  @override
  State<DailyClosingHistoryScreen> createState() => _DailyClosingHistoryScreenState();
}

class _DailyClosingHistoryScreenState extends State<DailyClosingHistoryScreen> {
  final _repository = DailyClosingRepository();
  List<Map<String, dynamic>> _history = [];
  bool _todayClosed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await _repository.getClosingHistory();
    final todayClosed = await _repository.isClosed(DailyClosingRepository.todayDateOnly());
    setState(() {
      _history = history;
      _todayClosed = todayClosed;
      _loading = false;
    });
  }

  Future<void> _closeToday() async {
    final today = DailyClosingRepository.todayDateOnly();
    final summary = await _repository.calculateDaySummary(today);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إقفال يومية اليوم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('عدد الفواتير: ${summary['invoice_count']}'),
            Text('إجمالي المبيعات: ${(summary['total_revenue'] as double).toStringAsFixed(2)} ج'),
            Text('صافي الربح: ${(summary['total_profit'] as double).toStringAsFixed(2)} ج'),
            Text('المصروفات: ${(summary['total_expenses'] as double).toStringAsFixed(2)} ج'),
            const Divider(),
            const Text(
              'بعد الإقفال، الأرقام دي هتتحفظ كصورة نهائية لليوم ولن تتغير.',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد الإقفال')),
        ],
      ),
    );

    if (confirmed != true) return;
    await _repository.closeDay(today, closedBy: CurrentSession.instance.user?.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إقفال اليومية')),
      floatingActionButton: _todayClosed
          ? null
          : FloatingActionButton.extended(
              onPressed: _closeToday,
              icon: const Icon(Icons.lock_outline),
              label: const Text('إقفال يومية اليوم'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: _todayClosed
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _todayClosed ? 'اليومية اتقفلت النهاردة بالفعل' : 'اليومية لسه مفتوحة النهاردة',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _history.isEmpty
                      ? const Center(child: Text('لا يوجد سجل إقفالات حتى الآن'))
                      : ListView.builder(
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final closing = _history[index];
                            return ListTile(
                              leading: const Icon(Icons.event_note_outlined),
                              title: Text(closing['closing_date'] as String),
                              subtitle: Text(
                                'فواتير: ${closing['invoice_count']}  •  '
                                'مبيعات: ${(closing['total_revenue'] as num).toStringAsFixed(2)} ج',
                              ),
                              trailing: Text(
                                'ربح: ${(closing['total_profit'] as num).toStringAsFixed(2)} ج',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
