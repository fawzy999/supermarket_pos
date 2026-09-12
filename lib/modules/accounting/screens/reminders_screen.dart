import 'package:flutter/material.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../inventory/repository/supplier_repository.dart';
import '../../reps/repository/rep_repository.dart';
import '../../reps/models/rep.dart';

/// شاشة التذكيرات: أقساط عقود الموردين المستحقة/المتأخرة + المناديب
/// اللي عليهم مديونية نقدية + مستندات قربت تنتهي/منتهية + مناديب
/// ناقصهم مستند أساسي - كل عنصر بيه زرار "واتساب" يبعت تذكير مباشر
/// بضغطة واحدة.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _supplierRepository = SupplierRepository();
  final _repRepository = RepRepository();

  List<Map<String, dynamic>> _installments = [];
  List<Map<String, dynamic>> _repDues = [];
  List<Map<String, dynamic>> _expiringRepDocs = [];
  List<Map<String, dynamic>> _expiringSupplierDocs = [];
  List<Rep> _repsMissingDocs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final installments = await _supplierRepository.getDueOrOverdueInstallments(withinDays: 3);
    final expiringRepDocs = await _repRepository.getExpiringDocuments(withinDays: 30);
    final expiringSupplierDocs = await _supplierRepository.getExpiringDocuments(withinDays: 30);
    final repsMissingDocs = await _repRepository.getRepsMissingCoreDocuments();

    // بنجيب بيانات المناديب كاملة (فيها التليفون) ونضم عليها ملخص الحساب
    final reps = await _repRepository.getAllReps();
    final repDues = <Map<String, dynamic>>[];
    for (final rep in reps) {
      final summary = await _repRepository.getRepAccountSummary(rep.id!);
      final cashOwed = summary['cash_owed'] as double;
      if (cashOwed > 0) {
        repDues.add({'name': rep.name, 'phone': rep.phone, 'cash_owed': cashOwed});
      }
    }
    repDues.sort((a, b) => (b['cash_owed'] as double).compareTo(a['cash_owed'] as double));

    setState(() {
      _installments = installments;
      _repDues = repDues;
      _expiringRepDocs = expiringRepDocs;
      _expiringSupplierDocs = expiringSupplierDocs;
      _repsMissingDocs = repsMissingDocs;
      _loading = false;
    });
  }

  bool _isDateOverdue(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    return d.isBefore(DateTime.now());
  }

  Future<void> _remindDocExpiry({required String? phone, required String name, required String docLabel, required String expiryDate, required bool overdue}) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد رقم تليفون مسجل')));
      return;
    }
    final text = overdue
        ? 'تنبيه: مستند "$docLabel" الخاص بك منتهي الصلاحية من ${expiryDate.substring(0, 10)} - برجاء تحديثه.'
        : 'تذكير: مستند "$docLabel" الخاص بك هينتهي في ${expiryDate.substring(0, 10)} - برجاء تجهيز نسخة جديدة.';
    await WhatsAppHelper.openChat(phone: phone, text: text);
  }

  bool _isOverdue(String dueDate) {
    final due = DateTime.tryParse(dueDate);
    if (due == null) return false;
    return due.isBefore(DateTime.now());
  }

  Future<void> _remindSupplier(Map<String, dynamic> installment) async {
    final phone = installment['phone'] as String?;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد رقم تليفون مسجل لهذا المورد')));
      return;
    }
    final dueDate = (installment['due_date'] as String).substring(0, 10);
    final amount = (installment['amount_due'] as num) - (installment['amount_paid'] as num);
    final text = 'تذكير سداد: قسط من عقد "${installment['contract_title']}" '
        'بمبلغ ${amount.toStringAsFixed(2)} ج، موعد استحقاقه $dueDate.';
    await WhatsAppHelper.openChat(phone: phone, text: text);
  }

  Future<void> _remindRep(Map<String, dynamic> repSummary) async {
    final phone = repSummary['phone'] as String?;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد رقم تليفون مسجل لهذا المندوب')));
      return;
    }
    final owed = (repSummary['cash_owed'] as double).toStringAsFixed(2);
    final text = 'تذكير: عليك مديونية نقدية مستحقة للمحل بقيمة $owed ج، برجاء التسوية في أقرب وقت.';
    await WhatsAppHelper.openChat(phone: phone, text: text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التذكيرات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Text('أقساط الموردين المستحقة (خلال ٣ أيام أو متأخرة)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_installments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('لا توجد أقساط مستحقة قريبًا'),
                    )
                  else
                    ..._installments.map((installment) {
                      final overdue = _isOverdue(installment['due_date'] as String);
                      final remaining = (installment['amount_due'] as num) - (installment['amount_paid'] as num);
                      return Card(
                        color: overdue ? Colors.red.shade50 : Colors.orange.shade50,
                        child: ListTile(
                          leading: Icon(overdue ? Icons.error_outline : Icons.schedule, color: overdue ? Colors.red : Colors.orange),
                          title: Text('${installment['company_name']} - ${installment['contract_title']}'),
                          subtitle: Text(
                            'المتبقي: ${remaining.toStringAsFixed(2)} ج  •  '
                            'الاستحقاق: ${(installment['due_date'] as String).substring(0, 10)}'
                            '${overdue ? '  (متأخر)' : ''}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.chat_outlined),
                            tooltip: 'تذكير واتساب',
                            onPressed: () => _remindSupplier(installment),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                  const Text('مناديب عليهم مديونية نقدية', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_repDues.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('لا يوجد مناديب عليهم مديونية نقدية حاليًا'),
                    )
                  else
                    ..._repDues.map((rep) => Card(
                          color: Colors.orange.shade50,
                          child: ListTile(
                            leading: const Icon(Icons.money_off, color: Colors.orange),
                            title: Text(rep['name'] as String),
                            subtitle: Text('مديونية نقدية: ${(rep['cash_owed'] as double).toStringAsFixed(2)} ج'),
                            trailing: IconButton(
                              icon: const Icon(Icons.chat_outlined),
                              tooltip: 'تذكير واتساب',
                              onPressed: () => _remindRep(rep),
                            ),
                          ),
                        )),
                  const SizedBox(height: 20),
                  const Text('مستندات قربت تنتهي أو منتهية', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_expiringRepDocs.isEmpty && _expiringSupplierDocs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('لا توجد مستندات قربت تنتهي خلال ٣٠ يوم'),
                    )
                  else ...[
                    ..._expiringRepDocs.map((doc) {
                      final expiry = doc['expiry_date'] as String;
                      final overdue = _isDateOverdue(expiry);
                      final label = (doc['title'] as String?) ?? (doc['doc_type'] as String? ?? 'مستند');
                      return Card(
                        color: overdue ? Colors.red.shade50 : Colors.orange.shade50,
                        child: ListTile(
                          leading: Icon(Icons.badge_outlined, color: overdue ? Colors.red : Colors.orange),
                          title: Text('${doc['rep_name']} - $label'),
                          subtitle: Text('${overdue ? 'منتهي منذ' : 'ينتهي في'}: ${expiry.substring(0, 10)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.chat_outlined),
                            tooltip: 'تذكير واتساب',
                            onPressed: () => _remindDocExpiry(
                              phone: doc['rep_phone'] as String?,
                              name: doc['rep_name'] as String,
                              docLabel: label,
                              expiryDate: expiry,
                              overdue: overdue,
                            ),
                          ),
                        ),
                      );
                    }),
                    ..._expiringSupplierDocs.map((doc) {
                      final expiry = doc['expiry_date'] as String;
                      final overdue = _isDateOverdue(expiry);
                      final label = (doc['title'] as String?) ?? (doc['doc_type'] as String? ?? 'مستند');
                      return Card(
                        color: overdue ? Colors.red.shade50 : Colors.orange.shade50,
                        child: ListTile(
                          leading: Icon(Icons.local_shipping_outlined, color: overdue ? Colors.red : Colors.orange),
                          title: Text('${doc['company_name']} - $label'),
                          subtitle: Text('${overdue ? 'منتهي منذ' : 'ينتهي في'}: ${expiry.substring(0, 10)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.chat_outlined),
                            tooltip: 'تذكير واتساب',
                            onPressed: () => _remindDocExpiry(
                              phone: doc['phone'] as String?,
                              name: doc['company_name'] as String,
                              docLabel: label,
                              expiryDate: expiry,
                              overdue: overdue,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 20),
                  const Text('مناديب ناقصهم بطاقة الرقم القومي', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_repsMissingDocs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('كل المناديب النشطين عندهم بطاقة الرقم القومي مسجلة'),
                    )
                  else
                    ..._repsMissingDocs.map((rep) => Card(
                          color: Colors.blueGrey.shade50,
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_outlined, color: Colors.blueGrey),
                            title: Text(rep.name),
                            subtitle: const Text('محتاج يضيف بطاقة الرقم القومي من بروفايله'),
                          ),
                        )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
