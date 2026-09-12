import 'package:flutter/material.dart';
import '../repository/cash_checkpoint_repository.dart';
import '../session/current_session.dart';

/// استلام نقدية من الخزنة (المدير/المحاسب): بيسجل إن الكاش الفعلي في
/// الدرج اتاخد (مثلاً عشان يورّد في البنك)، فالرصيد المتوقع يرجع صفر من
/// نفس اللحظة - من غير ما ده يقفل وردية أي كاشير شغال فعليًا.
class CashPickupScreen extends StatefulWidget {
  const CashPickupScreen({super.key});

  @override
  State<CashPickupScreen> createState() => _CashPickupScreenState();
}

class _CashPickupScreenState extends State<CashPickupScreen> {
  final _repository = CashCheckpointRepository();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  double? _expected;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final expected = await _repository.getExpectedCashSinceLastCheckpoint();
    setState(() {
      _expected = expected;
      _amountController.text = expected.toStringAsFixed(2);
      _loading = false;
    });
  }

  Future<void> _confirm() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب المبلغ الفعلي اللي استلمته بشكل صحيح')),
      );
      return;
    }
    final userId = CurrentSession.instance.user?.id;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد استلام الخزنة'),
        content: Text(
          'هتأكد إنك استلمت ${amount.toStringAsFixed(2)} ج فعليًا من الدرج، وإن الرصيد '
          'المتوقع هيرجع صفر من دلوقتي؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    await _repository.recordCheckpoint(
      byUserId: userId,
      actualAmount: amount,
      notes: _notesController.text,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استلام نقدية من الخزنة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('المبلغ الكاش المتوقع في الدرج حاليًا:'),
                        const SizedBox(height: 6),
                        Text(
                          '${(_expected ?? 0).toStringAsFixed(2)} ج',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'محسوب من كل مبيعات الكاش من آخر نقطة استلام مسجّلة لحد دلوقتي.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ الفعلي اللي استلمته',
                    suffixText: 'ج',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _confirm,
                    child: Text(_saving ? 'جاري الحفظ...' : 'تأكيد الاستلام'),
                  ),
                ),
              ],
            ),
    );
  }
}
