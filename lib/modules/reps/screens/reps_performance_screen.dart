import 'package:flutter/material.dart';
import '../repository/rep_repository.dart';

/// تقرير أداء عام لكل المناديب مع بعض: مبيعات كل واحد، تحصيله،
/// وطلبات التوصيل المعلّقة عليه.
class RepsPerformanceScreen extends StatefulWidget {
  const RepsPerformanceScreen({super.key});

  @override
  State<RepsPerformanceScreen> createState() => _RepsPerformanceScreenState();
}

class _RepsPerformanceScreenState extends State<RepsPerformanceScreen> {
  final _repository = RepRepository();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _repository.getAllRepsPerformance();
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير أداء المناديب')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('لا يوجد مناديب مسجلين'))
              : ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    final active = (row['active'] as int) == 1;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row['rep_name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                if (!active)
                                  const Chip(label: Text('غير نشط'), visualDensity: VisualDensity.compact),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('عدد فواتير البيع الخارجي: ${row['sales_count']}'),
                            Text('إجمالي مبيعاته: ${(row['sales_total'] as num).toStringAsFixed(2)} ج'),
                            Text('إجمالي ما حصّله: ${(row['collections_total'] as num).toStringAsFixed(2)} ج'),
                            Text('طلبات توصيل معلّقة: ${row['pending_deliveries']}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
