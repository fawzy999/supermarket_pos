import 'package:flutter/material.dart';
import '../repository/supply_batch_repository.dart';

/// موديول تنبيهات انتهاء الصلاحية: بيعرض كل الدفعات المنتهية فعلًا
/// (تحذير أحمر) والقريبة من الانتهاء خلال المدة المختارة (تحذير برتقالي)،
/// مجمّعة حسب الصنف، عبر كل المنتجات مش صنف واحد بس.
class ExpiryAlertsScreen extends StatefulWidget {
  const ExpiryAlertsScreen({super.key});

  @override
  State<ExpiryAlertsScreen> createState() => _ExpiryAlertsScreenState();
}

class _ExpiryAlertsScreenState extends State<ExpiryAlertsScreen> {
  final _repository = SupplyBatchRepository();
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  int _withinDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final alerts = await _repository.getExpiryAlerts(withinDays: _withinDays);
    setState(() {
      _alerts = alerts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final expiredCount = _alerts.where((a) => a['is_expired'] == true).length;
    final nearCount = _alerts.length - expiredCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنبيهات انتهاء الصلاحية'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'المدة',
            initialValue: _withinDays,
            onSelected: (value) {
              setState(() => _withinDays = value);
              _load();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 3, child: Text('خلال 3 أيام')),
              PopupMenuItem(value: 7, child: Text('خلال أسبوع')),
              PopupMenuItem(value: 14, child: Text('خلال أسبوعين')),
              PopupMenuItem(value: 30, child: Text('خلال شهر')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_alerts.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: expiredCount > 0 ? Colors.red.shade50 : Colors.orange.shade50,
                    child: Text(
                      '$expiredCount دفعة منتهية الصلاحية بالفعل  •  $nearCount قريبة من الانتهاء',
                      style: TextStyle(
                        color: expiredCount > 0 ? Colors.red.shade900 : Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: _alerts.isEmpty
                      ? const Center(child: Text('مفيش دفعات قريبة من الصلاحية أو منتهية حاليًا'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _alerts.length,
                            itemBuilder: (context, index) {
                              final batch = _alerts[index];
                              final isExpired = batch['is_expired'] == true;
                              final expiryDate = (batch['expiry_date'] as String).substring(0, 10);
                              return ListTile(
                                leading: Icon(
                                  isExpired ? Icons.error_outline : Icons.warning_amber_rounded,
                                  color: isExpired ? Colors.red : Colors.orange,
                                ),
                                title: Text(batch['product_name'] as String),
                                subtitle: Text(
                                  '${isExpired ? 'انتهت في' : 'تنتهي في'}: $expiryDate'
                                  '  •  الكمية: ${(batch['remaining_quantity'] as num).toStringAsFixed(0)}'
                                  '\nالمورد: ${batch['supplier_name'] ?? 'غير محدد'}',
                                ),
                                isThreeLine: true,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
