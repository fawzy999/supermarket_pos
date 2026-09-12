import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../customers/models/customer.dart';
import '../../customers/screens/customer_picker_screen.dart';
import '../../../core/auth/session/current_session.dart';
import '../models/rep.dart';
import '../repository/rep_repository.dart';
import '../services/rep_pdf_service.dart';
import '../../../core/widgets/signature_pad_dialog.dart';
import '../../../core/store_settings/store_settings_repository.dart';

/// حساب المندوب: تحصيل من العملاء، التسوية الدورية لعهدته، وتصدير
/// كشف حساب PDF كامل (مشاركة/طباعة/تنزيل) زي باقي التقارير في التطبيق.
class RepAccountScreen extends StatefulWidget {
  final Rep rep;

  const RepAccountScreen({super.key, required this.rep});

  @override
  State<RepAccountScreen> createState() => _RepAccountScreenState();
}

class _RepAccountScreenState extends State<RepAccountScreen> {
  final _repository = RepRepository();
  final _pdfService = RepPdfService();
  final _storeRepository = StoreSettingsRepository();

  List<Map<String, dynamic>> _collections = [];
  List<Map<String, dynamic>> _settlements = [];
  List<Map<String, dynamic>> _custodyBalance = [];
  Map<String, dynamic>? _accountSummary;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final collections = await _repository.getCollectionsForRep(widget.rep.id!);
    final settlements = await _repository.getSettlementsForRep(widget.rep.id!);
    final balance = await _repository.getCustodyBalance(widget.rep.id!);
    final accountSummary = await _repository.getRepAccountSummary(widget.rep.id!);
    setState(() {
      _collections = collections;
      _settlements = settlements;
      _custodyBalance = balance;
      _accountSummary = accountSummary;
      _loading = false;
    });
  }

  Future<void> _recordCollection() async {
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerPickerScreen()),
    );
    if (customer == null) return;

    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تحصيل من ${customer.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الرصيد الحالي على العميل: ${customer.balance.toStringAsFixed(2)} ج'),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'المبلغ المحصّل'),
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

    await _repository.recordCollection(
      repId: widget.rep.id!,
      customerId: customer.id!,
      amount: double.parse(amountController.text),
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
    );
    _load();
  }

  Future<void> _recordSettlement() async {
    Map<String, dynamic>? adjustedProduct;
    final quantityController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    final cashOwed = (_accountSummary?['cash_owed'] as double?) ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text('تسوية دورية للعهدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المديونية النقدية الحالية عليه: ${cashOwed.toStringAsFixed(2)} ج'),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'المبلغ النقدي المُسلَّم للمحل الآن (اختياري)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              const Text('لو فيه فرق جرد (نقص أو زيادة) في عهدة المندوب، اختر الصنف وسجّله:'),
              const SizedBox(height: 8),
              DropdownButton<Map<String, dynamic>>(
                isExpanded: true,
                hint: const Text('اختر صنف (اختياري)'),
                value: adjustedProduct,
                items: _custodyBalance
                    .map((row) => DropdownMenuItem(value: row, child: Text(row['product_name'] as String)))
                    .toList(),
                onChanged: (v) => dialogSetState(() => adjustedProduct = v),
              ),
              if (adjustedProduct != null)
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'الفرق (سالب للنقص، موجب للزيادة)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات التسوية'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسجيل التسوية')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    if (adjustedProduct != null && quantityController.text.trim().isNotEmpty) {
      final diff = double.tryParse(quantityController.text);
      if (diff != null && diff != 0) {
        await _repository.recordCustodyAdjustment(
          repId: widget.rep.id!,
          productId: adjustedProduct!['product_id'] as int,
          quantity: diff,
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );
      }
    }

    final settledAmount = double.tryParse(amountController.text.trim()) ?? 0;
    final settledNotes = notesController.text.trim().isEmpty ? null : notesController.text.trim();

    await _repository.recordSettlement(
      repId: widget.rep.id!,
      amount: settledAmount,
      notes: settledNotes,
      settledBy: CurrentSession.instance.user?.name,
    );
    _load();

    if (settledAmount > 0 && mounted) {
      await _offerSettlementVoucher(amount: settledAmount, notes: settledNotes);
    }
  }

  Future<void> _offerSettlementVoucher({required double amount, String? notes}) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اتسجلت التسوية'),
        content: const Text('عايز تطبع/تشارك سند بالتسوية دي؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('لأ، شكرًا')),
          TextButton(onPressed: () => Navigator.pop(context, 'share'), child: const Text('مشاركة')),
          TextButton(onPressed: () => Navigator.pop(context, 'print'), child: const Text('طباعة')),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('حفظ')),
        ],
      ),
    );
    if (action == null || !mounted) return;

    final repSignature = await SignaturePadDialog.show(context, title: 'توقيع المندوب (اختياري)');
    if (!mounted) return;
    final receiverSignature = await SignaturePadDialog.show(context, title: 'توقيع المستلم من المحل (اختياري)');
    if (!mounted) return;

    try {
      final storeSettings = await _storeRepository.getSettings();
      final file = await _pdfService.generateSettlementVoucher(
        rep: widget.rep,
        amountSettled: amount,
        date: DateTime.now().toIso8601String(),
        notes: notes,
        settledBy: CurrentSession.instance.user?.name,
        storeName: storeSettings['store_name'],
        repSignaturePath: repSignature,
        receiverSignaturePath: receiverSignature,
      );
      switch (action) {
        case 'share':
          await Share.shareXFiles([XFile(file.path)], text: 'سند تسوية: ${widget.rep.name}');
          break;
        case 'print':
          final bytes = await file.readAsBytes();
          await Printing.layoutPdf(onLayout: (_) async => bytes);
          break;
        case 'save':
          final documentsDir = await getApplicationDocumentsDirectory();
          final safeName = widget.rep.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
          final savedPath = '${documentsDir.path}/سند_تسوية_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          await file.copy(savedPath);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اتحفظ في: $savedPath')));
          }
          break;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    }
  }

  Future<void> _exportStatement(String action) async {
    setState(() => _exporting = true);
    try {
      final performance = await _repository.getRepPerformanceSummary(widget.rep.id!);
      final recentSales = await _repository.getExternalSalesForRep(widget.rep.id!);
      final file = await _pdfService.generateStatement(
        rep: widget.rep,
        custodyBalance: _custodyBalance,
        performance: performance,
        recentSales: recentSales.take(20).toList(),
      );
      switch (action) {
        case 'share':
          await Share.shareXFiles([XFile(file.path)], text: 'كشف حساب: ${widget.rep.name}');
          break;
        case 'print':
          final bytes = await file.readAsBytes();
          await Printing.layoutPdf(onLayout: (_) async => bytes);
          break;
        case 'save':
          final documentsDir = await getApplicationDocumentsDirectory();
          final safeName = widget.rep.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
          final savedPath = '${documentsDir.path}/كشف_حساب_مندوب_$safeName.pdf';
          await file.copy(savedPath);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اتحفظ في: $savedPath')));
          }
          break;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('حساب ${widget.rep.name}'),
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: 'تصدير كشف حساب',
                  onSelected: _exportStatement,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'share', child: Text('مشاركة الكشف')),
                    PopupMenuItem(value: 'print', child: Text('طباعة الكشف')),
                    PopupMenuItem(value: 'save', child: Text('تنزيل / حفظ في الجهاز')),
                  ],
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_accountSummary != null)
                  Card(
                    margin: const EdgeInsets.all(16),
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _recordCollection,
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('تسجيل تحصيل'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _recordSettlement,
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('تسوية دورية'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('سجل التحصيلات', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_collections.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد تحصيلات مسجلة بعد'))
                else
                  ..._collections.map((c) => ListTile(
                        leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                        title: Text('${c['customer_name']}  •  ${(c['amount'] as num).toStringAsFixed(2)} ج'),
                        subtitle: Text((c['date'] as String).substring(0, 16).replaceFirst('T', ' ')),
                      )),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('سجل التسويات الدورية', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_settlements.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد تسويات مسجلة بعد'))
                else
                  ..._settlements.map((s) {
                    final amount = (s['amount'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: Text((s['notes'] as String?) ?? 'تسوية بدون ملاحظات'),
                      subtitle: Text(
                        '${(s['date'] as String).substring(0, 16).replaceFirst('T', ' ')}'
                        '${s['settled_by'] != null ? '  •  بمعرفة: ${s['settled_by']}' : ''}',
                      ),
                      trailing: amount > 0
                          ? Text('${amount.toStringAsFixed(2)} ج', style: const TextStyle(fontWeight: FontWeight.bold))
                          : null,
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
