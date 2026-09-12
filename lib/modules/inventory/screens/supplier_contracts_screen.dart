import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../repository/supplier_repository.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/document_preview.dart';
import 'supplier_contract_form_screen.dart';

/// عقود التوريد الخاصة بالمورد - اختيارية، كل عقد ليه قيمة إجمالية وجدول
/// أقساط بمواعيد استحقاق، وتقدر تسجل سداد كل قسط كليًا أو جزئيًا.
class SupplierContractsScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierContractsScreen({super.key, required this.supplier});

  @override
  State<SupplierContractsScreen> createState() => _SupplierContractsScreenState();
}

class _SupplierContractsScreenState extends State<SupplierContractsScreen> {
  final _repository = SupplierRepository();
  List<Map<String, dynamic>> _contracts = [];
  Map<int, List<Map<String, dynamic>>> _installments = {};
  Map<int, List<Map<String, dynamic>>> _items = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final contracts = await _repository.getContractsForSupplier(widget.supplier.id!);
    final installmentsMap = <int, List<Map<String, dynamic>>>{};
    final itemsMap = <int, List<Map<String, dynamic>>>{};
    for (final contract in contracts) {
      final contractId = contract['id'] as int;
      installmentsMap[contractId] = await _repository.getInstallments(contractId);
      itemsMap[contractId] = await _repository.getItemsForContract(contractId);
    }
    setState(() {
      _contracts = contracts;
      _installments = installmentsMap;
      _items = itemsMap;
      _loading = false;
    });
  }

  Future<void> _addContract() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SupplierContractFormScreen(supplier: widget.supplier)),
    );
    if (result == true) _load();
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _addInstallment(int contractId) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? dueDate;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text('إضافة قسط/دفعة مستحقة'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ المستحق'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final parsed = double.tryParse(v ?? '');
                    if (parsed == null || parsed <= 0) return 'قيمة غير صحيحة';
                    return null;
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('موعد الاستحقاق'),
                  subtitle: Text(dueDate != null ? _formatDate(dueDate!) : 'غير محدد'),
                  trailing: const Icon(Icons.event_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) dialogSetState(() => dueDate = picked);
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
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await _repository.addInstallment(
      contractId: contractId,
      dueDate: dueDate?.toIso8601String(),
      amountDue: double.parse(amountController.text),
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
    );
    _load();
  }

  Future<void> _payInstallment(Map<String, dynamic> installment) async {
    final amountDue = (installment['amount_due'] as num).toDouble();
    final amountPaid = (installment['amount_paid'] as num).toDouble();
    final remaining = amountDue - amountPaid;
    final amountController = TextEditingController(text: remaining.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل سداد القسط'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('باقي على القسط: ${remaining.toStringAsFixed(2)} ج'),
              const SizedBox(height: 8),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'المبلغ المدفوع الآن'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed <= 0) return 'قيمة غير صحيحة';
                  return null;
                },
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

    await _repository.payInstallment(
      installmentId: installment['id'] as int,
      supplierId: widget.supplier.id!,
      amount: double.parse(amountController.text),
    );
    _load();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوع بالكامل';
      case 'partial':
        return 'مدفوع جزئيًا';
      default:
        return 'مستحق';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('عقود توريد ${widget.supplier.companyName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContract,
        icon: const Icon(Icons.add),
        label: const Text('عقد جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contracts.isEmpty
              ? const Center(child: Text('لا توجد عقود توريد مسجلة لهذا المورد'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: _contracts.map((contract) {
                    final total = (contract['total_amount'] as num).toDouble();
                    final paid = (contract['paid_total'] as num).toDouble();
                    final remaining = total - paid;
                    final installments = _installments[contract['id']] ?? [];
                    final items = _items[contract['id']] ?? [];
                    final startDate = contract['start_date'] as String?;
                    final endDate = contract['end_date'] as String?;
                    final durationLabel = contract['duration_label'] as String?;
                    final quotePath = contract['quote_file_path'] as String?;
                    final contractPath = contract['contract_file_path'] as String?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(contract['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'الإجمالي: ${total.toStringAsFixed(2)} ج  •  المدفوع: ${paid.toStringAsFixed(2)} ج  •  الباقي: ${remaining.toStringAsFixed(2)} ج',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (startDate != null)
                                  Text(
                                    'من ${startDate.substring(0, 10)}'
                                    '${endDate != null ? ' إلى ${endDate.substring(0, 10)}' : ''}',
                                  ),
                                if (durationLabel != null && durationLabel.trim().isNotEmpty)
                                  Text('مدة التوريد: $durationLabel'),
                                if ((contract['notes'] as String?)?.trim().isNotEmpty ?? false)
                                  Text('ملاحظات: ${contract['notes']}'),
                              ],
                            ),
                          ),
                          if (items.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Text('أصناف البضاعة', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            ...items.map((item) {
                              final quantity = item['quantity'] as num;
                              final unitPrice = (item['unit_price'] as num).toDouble();
                              final lineTotal = quantity.toDouble() * unitPrice;
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.inventory_2_outlined),
                                title: Text(item['item_name'] as String),
                                subtitle: Text(
                                  '${item['category_name'] ?? 'غير مصنّف'}  •  '
                                  '${formatQuantity(quantity)} ${item['unit'] ?? ''} × ${unitPrice.toStringAsFixed(2)} ج',
                                ),
                                trailing: Text('${lineTotal.toStringAsFixed(2)} ج'),
                              );
                            }),
                          ],
                          if (quotePath != null || contractPath != null) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Text('المرفقات', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            if (quotePath != null)
                              ListTile(
                                dense: true,
                                leading: SizedBox(width: 36, height: 36, child: DocumentPreview(path: quotePath)),
                                title: const Text('عرض السعر من المورد'),
                                onTap: () => openDocumentFile(context, quotePath),
                              ),
                            if (contractPath != null)
                              ListTile(
                                dense: true,
                                leading: SizedBox(width: 36, height: 36, child: DocumentPreview(path: contractPath)),
                                title: const Text('صورة/ملف العقد الموقّع'),
                                onTap: () => openDocumentFile(context, contractPath),
                              ),
                          ],
                          const Divider(height: 1),
                          if (installments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('لا توجد أقساط مسجلة بعد'),
                            )
                          else
                            ...installments.map((installment) {
                              final status = installment['status'] as String;
                              final dueDate = installment['due_date'] as String?;
                              return ListTile(
                                leading: Icon(Icons.event_outlined, color: _statusColor(status)),
                                title: Text('${(installment['amount_due'] as num).toStringAsFixed(2)} ج'
                                    '  •  مدفوع: ${(installment['amount_paid'] as num).toStringAsFixed(2)} ج'),
                                subtitle: Text(
                                  '${dueDate != null ? 'موعد الاستحقاق: ${dueDate.substring(0, 10)}' : 'بدون موعد محدد'}'
                                  '  •  ${_statusLabel(status)}',
                                ),
                                trailing: status != 'paid'
                                    ? TextButton(
                                        onPressed: () => _payInstallment(installment),
                                        child: const Text('تسجيل سداد'),
                                      )
                                    : null,
                              );
                            }),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: OutlinedButton.icon(
                              onPressed: () => _addInstallment(contract['id'] as int),
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة قسط جديد'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
