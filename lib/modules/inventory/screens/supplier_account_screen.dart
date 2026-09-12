import 'package:flutter/material.dart';
import '../../../core/auth/session/current_session.dart';
import '../models/supplier.dart';
import '../repository/supplier_repository.dart';

/// حساب المورد: الرصيد المستحق له من المحل، وكشف حساب كامل (مديونيات
/// ودفعات)، مع إمكانية تسجيل مديونية جديدة (توريدة بالأجل) أو دفعة سداد.
class SupplierAccountScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierAccountScreen({super.key, required this.supplier});

  @override
  State<SupplierAccountScreen> createState() => _SupplierAccountScreenState();
}

class _SupplierAccountScreenState extends State<SupplierAccountScreen> {
  final _repository = SupplierRepository();
  late Supplier _supplier;
  List<Map<String, dynamic>> _ledger = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final refreshed = await _repository.getSupplierById(_supplier.id!);
    final ledger = await _repository.getLedgerForSupplier(_supplier.id!);
    setState(() {
      _supplier = refreshed ?? _supplier;
      _ledger = ledger;
      _loading = false;
    });
  }

  Future<void> _recordEntry(String type) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'debt' ? 'تسجيل مديونية (توريدة بالأجل)' : 'تسجيل دفعة للمورد'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'المبلغ'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed <= 0) return 'قيمة غير صحيحة';
                  return null;
                },
              ),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final amount = double.parse(amountController.text);
    final notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
    final recordedBy = CurrentSession.instance.user?.name;

    if (type == 'debt') {
      await _repository.recordDebt(
        supplierId: _supplier.id!,
        amount: amount,
        notes: notes,
        recordedBy: recordedBy,
      );
    } else {
      await _repository.recordPayment(
        supplierId: _supplier.id!,
        amount: amount,
        notes: notes,
        recordedBy: recordedBy,
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('حساب ${_supplier.companyName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  color: _supplier.balance > 0 ? Colors.orange.shade50 : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الرصيد المستحق للمورد'),
                        const SizedBox(height: 4),
                        Text(
                          '${_supplier.balance.toStringAsFixed(2)} ج',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _recordEntry('debt'),
                          icon: const Icon(Icons.add_card_outlined),
                          label: const Text('تسجيل مديونية'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _recordEntry('payment'),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('تسجيل دفعة'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text('كشف الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_ledger.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد حركات مسجلة بعد'))
                else
                  ..._ledger.map((entry) {
                    final isDebt = entry['type'] == 'debt';
                    return ListTile(
                      leading: Icon(
                        isDebt ? Icons.arrow_upward : Icons.arrow_downward,
                        color: isDebt ? Colors.red : Colors.green,
                      ),
                      title: Text(isDebt ? 'مديونية جديدة' : 'دفعة مسددة'),
                      subtitle: Text(
                        '${(entry['date'] as String).substring(0, 16).replaceFirst('T', ' ')}'
                        '${entry['notes'] != null ? '\n${entry['notes']}' : ''}',
                      ),
                      isThreeLine: entry['notes'] != null,
                      trailing: Text(
                        '${(entry['amount'] as num).toStringAsFixed(2)} ج',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDebt ? Colors.red : Colors.green,
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
