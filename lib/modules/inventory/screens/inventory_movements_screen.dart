import 'package:flutter/material.dart';
import '../models/product.dart';
import '../repository/inventory_repository.dart';
import '../../../core/auth/session/current_session.dart';
import 'stock_adjustment_screen.dart';

/// سجل حركة المخزون: كل عمليات الدخول (توريد) والخروج (بيع) والتعديل
/// اليدوي، بالتاريخ والوقت بالساعة والدقيقة. لو اتفتحت لصنف معين، بتعرض
/// حركته بس، وبيظهر زرار "تعديل الكمية" للأدمن فقط.
class InventoryMovementsScreen extends StatefulWidget {
  final Product? product;

  const InventoryMovementsScreen({super.key, this.product});

  @override
  State<InventoryMovementsScreen> createState() => _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen> {
  final _repository = InventoryRepository();
  List<Map<String, dynamic>> _movements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final movements = await _repository.getMovementHistory(productId: widget.product?.id);
    setState(() {
      _movements = movements;
      _loading = false;
    });
  }

  String _formatDateTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
  }

  (String, Color, IconData) _typeInfo(String type) {
    switch (type) {
      case 'in':
        return ('توريد / دخول', Colors.green, Icons.arrow_downward_rounded);
      case 'out':
        return ('بيع / خروج', Colors.red, Icons.arrow_upward_rounded);
      case 'adjustment':
        return ('تعديل يدوي', Colors.blue, Icons.tune_rounded);
      case 'return_in':
        return ('مرتجع عميل', Colors.teal, Icons.assignment_return_outlined);
      case 'return_out':
        return ('مرتجع لمورد', Colors.purple, Icons.local_shipping_outlined);
      default:
        return (type, Colors.grey, Icons.swap_horiz_rounded);
    }
  }

  Future<void> _openAdjustment() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => StockAdjustmentScreen(product: widget.product!)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = CurrentSession.instance.isAdmin;
    final canAdjust = isAdmin && widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product != null
            ? 'حركة مخزون: ${widget.product!.name}'
            : 'سجل حركة المخزون'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _movements.isEmpty
              ? const Center(child: Text('لا توجد حركات مسجلة'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _movements.length,
                    itemBuilder: (context, index) {
                      final m = _movements[index];
                      final type = m['type'] as String;
                      final (label, color, icon) = _typeInfo(type);
                      final qty = (m['quantity'] as num).toDouble();
                      // 'in'/'return_in' مخزّنة بكمية موجبة تمثل زيادة،
                      // 'out'/'return_out' مخزّنة بكمية موجبة برضه لكنها
                      // تمثل نقص - لازم نحدد الإشارة حسب نوع الحركة نفسه
                      // مش حسب إشارة الرقم المخزّن. 'adjustment' وحدها
                      // بتتخزن بالفرق الفعلي (ممكن يكون سالب أصلًا).
                      final displayQty = (type == 'out' || type == 'return_out') ? -qty : qty;
                      return ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(
                          widget.product != null
                              ? label
                              : '${m['product_name']}  •  $label',
                        ),
                        subtitle: Text(_formatDateTime(m['date'] as String)),
                        trailing: Text(
                          '${displayQty > 0 ? '+' : ''}${displayQty.toStringAsFixed(0)}',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: canAdjust
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('تعديل الكمية'),
              onPressed: _openAdjustment,
            )
          : null,
    );
  }
}
