import 'dart:io';
import 'package:flutter/material.dart';
import '../models/rep.dart';
import '../repository/rep_repository.dart';
import 'rep_account_screen.dart';
import 'rep_custody_screen.dart';
import 'rep_delivery_screen.dart';
import 'rep_external_sale_screen.dart';
import 'rep_form_screen.dart';
import 'rep_documents_screen.dart';
import '../../../core/utils/whatsapp_helper.dart';

/// بروفايل المندوب: بياناته، ملخص أدائه السريع، وبوابة الدخول لكل
/// أنشطته - عهدة البضاعة، البيع الخارجي، طلبات التوصيل، والحساب
/// (تحصيل + تسوية + كشف حساب PDF).
class RepProfileScreen extends StatefulWidget {
  final Rep rep;

  const RepProfileScreen({super.key, required this.rep});

  @override
  State<RepProfileScreen> createState() => _RepProfileScreenState();
}

class _RepProfileScreenState extends State<RepProfileScreen> {
  final _repository = RepRepository();
  late Rep _rep;
  Map<String, dynamic>? _performance;
  Map<String, dynamic>? _accountSummary;
  List<Map<String, dynamic>> _recentSales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _rep = widget.rep;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final refreshed = await _repository.getRepById(_rep.id!);
    final performance = await _repository.getRepPerformanceSummary(_rep.id!);
    final accountSummary = await _repository.getRepAccountSummary(_rep.id!);
    final sales = await _repository.getExternalSalesForRep(_rep.id!);
    setState(() {
      _rep = refreshed ?? _rep;
      _performance = performance;
      _accountSummary = accountSummary;
      _recentSales = sales;
      _loading = false;
    });
  }

  Future<void> _editRep() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RepFormScreen(rep: _rep)));
    _load();
  }

  Future<void> _openDocuments() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RepDocumentsScreen(rep: _rep)));
  }

  Future<void> _openCustody() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RepCustodyScreen(rep: _rep)));
    _load();
  }

  Future<void> _openExternalSale() async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RepExternalSaleScreen(rep: _rep)),
    );
    if (done == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اتسجلت فاتورة البيع الخارجي')));
    }
    _load();
  }

  Future<void> _openDeliveries() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RepDeliveryScreen(rep: _rep)));
    _load();
  }

  Future<void> _openAccount() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RepAccountScreen(rep: _rep)));
    _load();
  }

  Future<void> _openWhatsApp() async {
    final phone = _rep.phone;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد رقم تليفون مسجل لهذا المندوب')));
      return;
    }
    final opened = await WhatsAppHelper.openChat(phone: phone, text: 'مرحبًا ${_rep.name}،');
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مقدرناش نفتح واتساب - تأكد إنه متثبت')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final performance = _performance;

    return Scaffold(
      appBar: AppBar(
        title: Text(_rep.name),
        actions: [
          IconButton(icon: const Icon(Icons.chat_outlined), tooltip: 'فتح واتساب', onPressed: _openWhatsApp),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editRep),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: (_rep.photoPath != null && File(_rep.photoPath!).existsSync())
                              ? FileImage(File(_rep.photoPath!)) as ImageProvider
                              : null,
                          child: (_rep.photoPath == null || !File(_rep.photoPath!).existsSync())
                              ? const Icon(Icons.person_outline, size: 32)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(_rep.name,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                  if (!_rep.active)
                                    const Chip(label: Text('غير نشط'), visualDensity: VisualDensity.compact),
                                ],
                              ),
                              if ((_rep.phone ?? '').isNotEmpty) Text('التليفون: ${_rep.phone}'),
                              if ((_rep.email ?? '').isNotEmpty) Text('الإيميل: ${_rep.email}'),
                              if ((_rep.nationalId ?? '').isNotEmpty) Text('الرقم القومي: ${_rep.nationalId}'),
                              if ((_rep.address ?? '').isNotEmpty) Text('العنوان: ${_rep.address}'),
                              if ((_rep.notes ?? '').isNotEmpty) Text('ملاحظات: ${_rep.notes}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (performance != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statChip('مبيعاته', '${(performance['sales_total'] as num).toStringAsFixed(0)} ج'),
                        _statChip('حصّله', '${(performance['collections_total'] as num).toStringAsFixed(0)} ج'),
                        _statChip('توصيل معلّق', '${performance['pending_deliveries_count']}'),
                        _statChip('توصيل مكتمل', '${performance['delivered_count']}'),
                      ],
                    ),
                  ),

                if (_accountSummary != null)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ملخص الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('بضاعة تحت عهدته: '
                              '${(_accountSummary!['custody_value'] as double).toStringAsFixed(2)} ج'),
                          Text('مديونية نقدية عليه: '
                              '${(_accountSummary!['cash_owed'] as double).toStringAsFixed(2)} ج'),
                          const Divider(),
                          Text(
                            'إجمالي المستحق منه: '
                            '${(_accountSummary!['total_due'] as double).toStringAsFixed(2)} ج',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.4,
                    children: [
                      _actionCard('عهدة البضاعة', Icons.inventory_2_outlined, _openCustody),
                      _actionCard('بيع خارجي', Icons.point_of_sale_outlined, _openExternalSale),
                      _actionCard('طلبات التوصيل', Icons.local_shipping_outlined, _openDeliveries),
                      _actionCard('الحساب والتسوية', Icons.receipt_long_outlined, _openAccount),
                      _actionCard('المستندات', Icons.folder_outlined, _openDocuments),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text('آخر فواتير البيع الخارجي', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_recentSales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لا توجد فواتير بيع خارجي مسجلة بعد'),
                  )
                else
                  ..._recentSales.take(10).map((sale) {
                    final label = sale['payment_method'] == 'credit' ? 'آجل' : 'كاش';
                    return ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text('${(sale['customer_name'] as String?) ?? 'عميل غير مسجل'}  •  $label'),
                      subtitle: Text((sale['date'] as String).substring(0, 16).replaceFirst('T', ' ')),
                      trailing: Text('${(sale['total_amount'] as num).toStringAsFixed(2)} ج'),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _statChip(String label, String value) => Chip(
        label: Text('$label: $value'),
      );

  Widget _actionCard(String label, IconData icon, VoidCallback onTap) => Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      );
}
