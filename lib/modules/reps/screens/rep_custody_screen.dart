import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../inventory/models/product.dart';
import '../../sales/screens/product_picker_screen.dart';
import '../../../core/auth/session/current_session.dart';
import '../../../core/store_settings/store_settings_repository.dart';
import '../models/rep.dart';
import '../repository/rep_repository.dart';
import '../services/rep_pdf_service.dart';
import '../../../core/widgets/signature_pad_dialog.dart';

/// شاشة عهدة المندوب: سحب بضاعة من المخزون الرئيسي لعهدته، إرجاع
/// الفائض، ورصيده الحالي من كل صنف + سجل الحركة بالكامل.
class RepCustodyScreen extends StatefulWidget {
  final Rep rep;

  const RepCustodyScreen({super.key, required this.rep});

  @override
  State<RepCustodyScreen> createState() => _RepCustodyScreenState();
}

class _RepCustodyScreenState extends State<RepCustodyScreen> {
  final _repository = RepRepository();
  final _pdfService = RepPdfService();
  final _storeRepository = StoreSettingsRepository();
  List<Map<String, dynamic>> _balance = [];
  List<Map<String, dynamic>> _ledger = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final balance = await _repository.getCustodyBalance(widget.rep.id!);
    final ledger = await _repository.getCustodyLedger(widget.rep.id!);
    setState(() {
      _balance = balance;
      _ledger = ledger;
      _loading = false;
    });
  }

  Future<void> _withdraw() async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductPickerScreen()),
    );
    if (product == null) return;
    final quantity = await _askQuantity(title: 'كمية السحب لعهدة ${widget.rep.name}');
    if (quantity == null) return;

    await _repository.withdrawToCustody(
      repId: widget.rep.id!,
      productId: product.id!,
      quantity: quantity,
    );
    _load();
    if (mounted) {
      await _offerVoucher(type: 'withdraw', productName: product.name, quantity: quantity, unit: product.unit ?? 'قطعة');
    }
  }

  Future<void> _return() async {
    if (_balance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مفيش بضاعة في عهدة المندوب حاليًا')),
      );
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر الصنف المرتجع'),
        children: _balance
            .map((row) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, row),
                  child: Text('${row['product_name']}  (معاه: ${(row['remaining'] as num).toStringAsFixed(0)})'),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;

    final quantity = await _askQuantity(title: 'كمية الإرجاع من ${selected['product_name']}');
    if (quantity == null) return;

    await _repository.returnFromCustody(
      repId: widget.rep.id!,
      productId: selected['product_id'] as int,
      quantity: quantity,
    );
    _load();
    if (mounted) {
      await _offerVoucher(
        type: 'return',
        productName: selected['product_name'] as String,
        quantity: quantity,
        unit: 'قطعة',
      );
    }
  }

  Future<void> _offerVoucher({
    required String type,
    required String productName,
    required double quantity,
    required String unit,
  }) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اتسجلت الحركة'),
        content: const Text('عايز تطبع/تشارك سند بالعملية دي؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('لأ، شكرًا')),
          TextButton(onPressed: () => Navigator.pop(context, 'share'), child: const Text('مشاركة')),
          TextButton(onPressed: () => Navigator.pop(context, 'print'), child: const Text('طباعة')),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('حفظ')),
        ],
      ),
    );
    if (action == null || !mounted) return;

    // توقيع رقمي اختياري (تقدر تتخطاه بزرار "تخطي" في أي وقت)
    final repSignature = await SignaturePadDialog.show(context, title: 'توقيع المندوب (اختياري)');
    if (!mounted) return;
    final receiverSignature = await SignaturePadDialog.show(context, title: 'توقيع المستلم من المحل (اختياري)');
    if (!mounted) return;

    try {
      final storeSettings = await _storeRepository.getSettings();
      final file = await _pdfService.generateCustodyVoucher(
        rep: widget.rep,
        type: type,
        productName: productName,
        quantity: quantity,
        unit: unit,
        date: DateTime.now().toIso8601String(),
        receivedBy: CurrentSession.instance.user?.name,
        storeName: storeSettings['store_name'],
        repSignaturePath: repSignature,
        receiverSignaturePath: receiverSignature,
      );
      switch (action) {
        case 'share':
          await Share.shareXFiles([XFile(file.path)], text: 'سند عهدة: ${widget.rep.name}');
          break;
        case 'print':
          final bytes = await file.readAsBytes();
          await Printing.layoutPdf(onLayout: (_) async => bytes);
          break;
        case 'save':
          final documentsDir = await getApplicationDocumentsDirectory();
          final safeName = widget.rep.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
          final savedPath = '${documentsDir.path}/سند_عهدة_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
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

  Future<double?> _askQuantity({required String title}) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'الكمية'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'الكمية مطلوبة';
              final parsed = double.tryParse(v);
              if (parsed == null || parsed <= 0) return 'قيمة غير صحيحة';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    return double.parse(controller.text);
  }

  String _typeLabel(String type) => switch (type) {
        'withdraw' => 'سحب من المخزون',
        'return' => 'إرجاع للمخزون',
        'sale' => 'بيع خارجي',
        'adjustment' => 'تسوية',
        _ => type,
      };

  Color _typeColor(String type) => switch (type) {
        'withdraw' => Colors.blue,
        'return' => Colors.green,
        'sale' => Colors.deepOrange,
        'adjustment' => Colors.purple,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('عهدة ${widget.rep.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _withdraw,
                          icon: const Icon(Icons.upload_outlined),
                          label: const Text('سحب بضاعة'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _return,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('إرجاع فائض'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('الرصيد الحالي في عهدته', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_balance.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('مفيش بضاعة في عهدته حاليًا'),
                  )
                else
                  ..._balance.map((row) => ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(row['product_name'] as String),
                        trailing: Text(
                          (row['remaining'] as num).toStringAsFixed(0),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('سجل حركة العهدة', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_ledger.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لا توجد حركات مسجلة بعد'),
                  )
                else
                  ..._ledger.map((entry) {
                    final type = entry['type'] as String;
                    final qty = (entry['quantity'] as num).toDouble();
                    return ListTile(
                      leading: Icon(Icons.circle, size: 12, color: _typeColor(type)),
                      title: Text('${entry['product_name']}  •  ${_typeLabel(type)}'),
                      subtitle: Text((entry['date'] as String).substring(0, 16).replaceFirst('T', ' ')),
                      trailing: Text(qty.toStringAsFixed(0)),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
