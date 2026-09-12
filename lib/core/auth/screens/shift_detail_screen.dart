import 'package:flutter/material.dart';
import '../models/shift.dart';
import '../repository/shift_repository.dart';
import '../session/current_session.dart';

class ShiftDetailScreen extends StatefulWidget {
  final int shiftId;
  final String userName;

  const ShiftDetailScreen({super.key, required this.shiftId, required this.userName});

  @override
  State<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends State<ShiftDetailScreen> {
  final _repository = ShiftRepository();
  Shift? _shift;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _appEvents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shift = await _repository.getShift(widget.shiftId);
    if (shift != null) {
      final invoices = await _repository.getInvoicesForShift(
        shift.userId,
        shift.loginTime,
        shift.logoutTime,
      );
      final appEvents = await _repository.getAppEventsForShift(shift.id!);
      setState(() {
        _shift = shift;
        _invoices = invoices;
        _appEvents = appEvents;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmReceipt() async {
    final currentUserId = CurrentSession.instance.user?.id;
    if (currentUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد استلام العهدة'),
        content: Text(
          'بتأكد إنك استلمت من ${widget.userName} مبلغ '
          '${(_shift!.cashTotal ?? 0).toStringAsFixed(2)} ج كاش فعليًا؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد الاستلام')),
        ],
      ),
    );

    if (confirmed != true) return;
    await _repository.confirmReceipt(widget.shiftId, currentUserId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_shift == null) {
      return const Scaffold(body: Center(child: Text('الوردية غير موجودة')));
    }

    final shift = _shift!;
    final isClosed = shift.logoutTime != null;

    return Scaffold(
      appBar: AppBar(title: Text('وردية ${widget.userName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isClosed)
            Card(
              color: Colors.green.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(child: Text('الوردية لسه شغالة - الأرقام دي لحظية لحد دلوقتي')),
                  ],
                ),
              ),
            ),
          if (!isClosed) const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('دخول: ${shift.loginTime.substring(0, 16).replaceFirst('T', '  ')}'),
                  Text(
                    isClosed
                        ? 'خروج: ${shift.logoutTime!.substring(0, 16).replaceFirst('T', '  ')}'
                        : 'لسه شغال دلوقتي',
                    style: TextStyle(color: isClosed ? null : Colors.green),
                  ),
                  const Divider(),
                  Text('عدد الفواتير: ${shift.invoiceCount ?? _invoices.length}'),
                  Text(
                    'إجمالي الكاش: ${(shift.cashTotal ?? 0).toStringAsFixed(2)} ج',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('إجمالي الفيزا/البطاقة: ${(shift.cardTotal ?? 0).toStringAsFixed(2)} ج'),
                  Text(
                    'الإجمالي الكلي: ${(shift.totalAmount ?? 0).toStringAsFixed(2)} ج',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isClosed)
            Card(
              color: shift.isConfirmed
                  ? Colors.green.shade50
                  : Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.isConfirmed ? 'العهدة اتأكد استلامها ✓' : 'العهدة لسه ما اتأكدش استلامها',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (shift.isConfirmed) ...[
                      const SizedBox(height: 4),
                      Text('اتأكدت الساعة: ${shift.confirmedAt?.substring(0, 16).replaceFirst('T', '  ') ?? ''}'),
                      if (shift.receivedAmount != null)
                        Text('المبلغ الفعلي اللي اتسلّم: ${shift.receivedAmount!.toStringAsFixed(2)} ج'),
                    ] else ...[
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _confirmReceipt,
                        child: const Text('تأكيد إني استلمت العهدة دي'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('الفواتير خلال الوردية', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد فواتير في الوردية دي'),
            )
          else
            ..._invoices.map((invoice) {
              final paymentLabel = invoice['payment_method'] == 'cash' ? 'كاش' : 'فيزا/بطاقة';
              return ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('فاتورة #${invoice['id']}'),
                subtitle: Text(
                  '${(invoice['date'] as String).substring(0, 16)}  •  $paymentLabel',
                ),
                trailing: Text(
                  '${(invoice['total_amount'] as num).toStringAsFixed(2)} ج',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          if (_appEvents.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('سجل فتح/قفل التطبيق خلال الوردية', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._appEvents.map((event) {
              final isOpenEvent = event['event'] == 'open';
              return ListTile(
                dense: true,
                leading: Icon(
                  isOpenEvent ? Icons.lock_open_outlined : Icons.lock_outline,
                  size: 18,
                  color: isOpenEvent ? Colors.green : Colors.grey,
                ),
                title: Text(isOpenEvent ? 'اتفتح' : 'اتقفل'),
                subtitle: Text((event['at'] as String).substring(0, 16).replaceFirst('T', '  ')),
              );
            }),
          ],
        ],
      ),
    );
  }
}
