import 'package:flutter/material.dart';
import '../models/product.dart';
import '../repository/inventory_repository.dart';

/// شاشة تعديل يدوي لكمية صنف - متاحة للأدمن فقط (يتم التحقق من الصلاحية
/// قبل فتح الشاشة، في شاشة سجل الحركة). أي تعديل هنا بيتسجل تلقائيًا
/// كحركة "تعديل" في سجل حركة المخزون، بالفرق (زيادة أو نقص) والتاريخ والوقت.
class StockAdjustmentScreen extends StatefulWidget {
  final Product product;

  const StockAdjustmentScreen({super.key, required this.product});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = InventoryRepository();
  late final TextEditingController _quantityController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.product.quantity.toStringAsFixed(0));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final newQuantity = double.parse(_quantityController.text);

    setState(() => _saving = true);
    await _repository.adjustQuantity(widget.product.id!, newQuantity);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تعديل كمية: ${widget.product.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'الكمية الحالية المسجلة: ${widget.product.quantity.toStringAsFixed(0)}'
              '${widget.product.unit != null ? ' ${widget.product.unit}' : ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'الكمية الصحيحة بعد الجرد'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'الكمية مطلوبة';
                if (double.tryParse(v) == null) return 'قيمة غير صحيحة';
                if (double.parse(v) < 0) return 'الكمية لا يمكن أن تكون سالبة';
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'هذا التعديل هيتسجل في سجل حركة المخزون بالفرق والتاريخ والوقت، '
              'ولن يغيّر الكمية المتبقية في دفعات التوريد نفسها.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'جاري الحفظ...' : 'حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }
}
