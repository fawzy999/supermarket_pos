import 'package:flutter/material.dart';
import '../models/rep.dart';
import '../repository/rep_repository.dart';

/// طلبات التوصيل اللي المندوب مسؤول عنها: تكليفه بفاتورة من المحل
/// (أو طلب مباشر بعنوان)، وتحديث حالة التسليم لحظة بلحظة.
class RepDeliveryScreen extends StatefulWidget {
  final Rep rep;

  const RepDeliveryScreen({super.key, required this.rep});

  @override
  State<RepDeliveryScreen> createState() => _RepDeliveryScreenState();
}

class _RepDeliveryScreenState extends State<RepDeliveryScreen> {
  final _repository = RepRepository();
  List<Map<String, dynamic>> _deliveries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final deliveries = await _repository.getDeliveriesForRep(widget.rep.id!);
    setState(() {
      _deliveries = deliveries;
      _loading = false;
    });
  }

  Future<void> _assignNewDelivery() async {
    final source = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('تكليف بتوصيل'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'store_sale'),
            child: const Text('ربط بفاتورة بيع من المحل'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'manual'),
            child: const Text('طلب توصيل مباشر (بعنوان)'),
          ),
        ],
      ),
    );
    if (source == null) return;

    if (source == 'store_sale') {
      await _assignFromStoreSale();
    } else {
      await _assignManual();
    }
    _load();
  }

  Future<void> _assignFromStoreSale() async {
    final sales = await _repository.getRecentStoreSales();
    if (sales.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد فواتير بيع مسجلة')));
      }
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر الفاتورة'),
        children: sales
            .map((sale) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, sale),
                  child: Text(
                    'فاتورة #${sale['id']}  •  ${(sale['total_amount'] as num).toStringAsFixed(2)} ج'
                    '  •  ${(sale['date'] as String).substring(0, 10)}',
                  ),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;

    await _repository.createDelivery(
      repId: widget.rep.id!,
      saleId: selected['id'] as int,
      customerName: selected['customer_name'] as String?,
      customerPhone: selected['customer_phone'] as String?,
    );
  }

  Future<void> _assignManual() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلب توصيل مباشر'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم العميل'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'التليفون'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'العنوان'),
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
            child: const Text('تكليف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _repository.createDelivery(
      repId: widget.rep.id!,
      customerName: nameController.text.trim(),
      customerPhone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
      address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
    );
  }

  Future<void> _updateStatus(Map<String, dynamic> delivery) async {
    final status = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('تحديث حالة التسليم'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'delivered'), child: const Text('✅ تم التسليم')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'returned'), child: const Text('↩️ مرتجع')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'postponed'), child: const Text('⏳ مؤجل')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'pending'), child: const Text('🔄 لسه معلّق')),
        ],
      ),
    );
    if (status == null) return;

    await _repository.updateDeliveryStatus(deliveryId: delivery['id'] as int, status: status);
    _load();
  }

  String _statusLabel(String status) => switch (status) {
        'delivered' => 'تم التسليم',
        'returned' => 'مرتجع',
        'postponed' => 'مؤجل',
        _ => 'معلّق',
      };

  Color _statusColor(String status) => switch (status) {
        'delivered' => Colors.green,
        'returned' => Colors.red,
        'postponed' => Colors.orange,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('توصيل - ${widget.rep.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _assignNewDelivery,
        icon: const Icon(Icons.add),
        label: const Text('تكليف بتوصيل'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deliveries.isEmpty
              ? const Center(child: Text('لا توجد طلبات توصيل مسندة لهذا المندوب'))
              : ListView.builder(
                  itemCount: _deliveries.length,
                  itemBuilder: (context, index) {
                    final delivery = _deliveries[index];
                    final status = delivery['status'] as String;
                    return ListTile(
                      leading: Icon(Icons.local_shipping_outlined, color: _statusColor(status)),
                      title: Text(
                        (delivery['customer_name'] as String?) ??
                            (delivery['sale_id'] != null ? 'فاتورة #${delivery['sale_id']}' : 'طلب توصيل'),
                      ),
                      subtitle: Text(
                        '${(delivery['address'] as String?) ?? ((delivery['customer_phone'] as String?) ?? '')}\n'
                        'اتكلف: ${(delivery['assigned_at'] as String).substring(0, 16).replaceFirst('T', ' ')}',
                      ),
                      isThreeLine: true,
                      trailing: Chip(
                        label: Text(_statusLabel(status)),
                        backgroundColor: _statusColor(status).withOpacity(0.15),
                        labelStyle: TextStyle(color: _statusColor(status)),
                      ),
                      onTap: () => _updateStatus(delivery),
                    );
                  },
                ),
    );
  }
}
