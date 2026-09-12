import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../repository/customer_repository.dart';
import 'customer_form_screen.dart';
import '../../../core/auth/session/current_session.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../sales/screens/invoice_screen.dart';
import 'order_catalog_screen.dart';

/// بروفايل العميل: رصيده الحالي، سجل فواتيره الآجلة، وسجل التحصيلات منه.
class CustomerProfileScreen extends StatefulWidget {
  final Customer customer;

  const CustomerProfileScreen({super.key, required this.customer});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _repository = CustomerRepository();
  late Customer _customer;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final refreshed = await _repository.getCustomerById(_customer.id!);
    final sales = await _repository.getSalesForCustomer(_customer.id!);
    final payments = await _repository.getPaymentsForCustomer(_customer.id!);
    setState(() {
      _customer = refreshed ?? _customer;
      _sales = sales;
      _payments = payments;
      _loading = false;
    });
  }

  Future<void> _adjustLoyaltyPoints() async {
    final pointsController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل نقاط الولاء'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الرصيد الحالي: ${_customer.loyaltyPoints} نقطة'),
              const SizedBox(height: 12),
              TextFormField(
                controller: pointsController,
                decoration: const InputDecoration(
                  labelText: 'عدد النقاط (موجب لإضافة/كسب، سالب لاستبدال/خصم)',
                ),
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                validator: (v) {
                  final parsed = int.tryParse(v ?? '');
                  if (parsed == null || parsed == 0) return 'قيمة غير صحيحة';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'السبب (اختياري)'),
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

    await _repository.addLoyaltyPoints(
      customerId: _customer.id!,
      points: int.parse(pointsController.text),
      reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
    );
    _load();
  }

  Future<void> _openWhatsApp() async {
    final phone = _customer.phone;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد رقم تليفون مسجل لهذا العميل')));
      return;
    }
    final text = _customer.hasDebt
        ? 'مرحبًا ${_customer.name}، تذكير بسيط: عليك رصيد مستحق قدره ${_customer.balance.toStringAsFixed(2)} ج.'
        : 'مرحبًا ${_customer.name}،';
    final opened = await WhatsAppHelper.openChat(phone: phone, text: text);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مقدرناش نفتح واتساب - تأكد إنه متثبت')));
    }
  }

  Future<void> _editCustomer() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: _customer)),
    );
    _load();
  }

  Future<void> _recordPayment() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل تحصيل'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الرصيد الحالي: ${_customer.balance.toStringAsFixed(2)} ج'),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'المبلغ المحصّل'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'المبلغ مطلوب';
                  final parsed = double.tryParse(v);
                  if (parsed == null || parsed <= 0) return 'قيمة غير صحيحة';
                  return null;
                },
              ),
              const SizedBox(height: 12),
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

    await _repository.recordPayment(
      customerId: _customer.id!,
      amount: double.parse(amountController.text),
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      receivedBy: CurrentSession.instance.user?.name,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'كتالوج الطلب',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OrderCatalogScreen(customer: _customer)),
            ),
          ),
          IconButton(icon: const Icon(Icons.chat_outlined), tooltip: 'فتح واتساب', onPressed: _openWhatsApp),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editCustomer),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Container(
                  width: double.infinity,
                  color: _customer.hasDebt
                      ? Colors.orange.shade100
                      : Theme.of(context).colorScheme.primaryContainer,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرصيد الحالي: ${_customer.balance.toStringAsFixed(2)} ج',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_customer.hasDebt)
                        const Text('عليه مديونية قائمة (بيع آجل لسه ماتحصلش)',
                            style: TextStyle(color: Colors.deepOrange)),
                      if (_customer.phone != null) Text('التليفون: ${_customer.phone}'),
                      if (_customer.address != null) Text('العنوان: ${_customer.address}'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _recordPayment,
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('تسجيل تحصيل'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _adjustLoyaltyPoints,
                          icon: const Icon(Icons.stars_outlined),
                          label: Text('نقاط الولاء (${_customer.loyaltyPoints})'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('الفواتير المرتبطة', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_sales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لا توجد فواتير مرتبطة بهذا العميل حتى الآن'),
                  )
                else
                  ..._sales.map((s) {
                    final paymentMethod = s['payment_method'] as String;
                    final label = switch (paymentMethod) {
                      'cash' => 'كاش',
                      'card' => 'فيزا/بطاقة',
                      'credit' => 'حساب عميل',
                      'rep_account' => 'حساب مندوب',
                      _ => 'فيزا/بطاقة',
                    };
                    return ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text('فاتورة #${s['id']}  •  $label'),
                      subtitle: Text((s['date'] as String).substring(0, 16)),
                      trailing: Text('${(s['total_amount'] as num).toStringAsFixed(2)} ج'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => InvoiceScreen(saleId: s['id'] as int)),
                      ),
                    );
                  }),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('سجل التحصيلات', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لا توجد تحصيلات مسجلة حتى الآن'),
                  )
                else
                  ..._payments.map((p) => ListTile(
                        leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                        title: Text('${(p['amount'] as num).toStringAsFixed(2)} ج'),
                        subtitle: Text(
                          '${(p['date'] as String).substring(0, 16)}'
                          '${p['received_by'] != null ? '  •  استلمها: ${p['received_by']}' : ''}'
                          '${p['notes'] != null ? '\n${p['notes']}' : ''}',
                        ),
                        isThreeLine: p['notes'] != null,
                      )),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
