import 'package:flutter/material.dart';
import '../repository/cash_checkpoint_repository.dart';

/// سجل كل نقاط استلام نقدية الخزنة - كل نقطة بمين استلمها ووقتها والمبلغ
/// المتوقع مقابل الفعلي، عشان تقدر تراجع أي فروقات على مدار الوقت بسهولة.
class CashCheckpointsHistoryScreen extends StatefulWidget {
  const CashCheckpointsHistoryScreen({super.key});

  @override
  State<CashCheckpointsHistoryScreen> createState() => _CashCheckpointsHistoryScreenState();
}

class _CashCheckpointsHistoryScreenState extends State<CashCheckpointsHistoryScreen> {
  final _repository = CashCheckpointRepository();
  List<Map<String, dynamic>> _checkpoints = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final checkpoints = await _repository.getAllCheckpoints();
    setState(() {
      _checkpoints = checkpoints;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل استلام نقدية الخزنة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _checkpoints.isEmpty
              ? const Center(child: Text('لا توجد نقاط استلام مسجلة بعد'))
              : ListView.builder(
                  itemCount: _checkpoints.length,
                  itemBuilder: (context, index) {
                    final checkpoint = _checkpoints[index];
                    final expected = (checkpoint['expected_amount'] as num).toDouble();
                    final actual = (checkpoint['actual_amount'] as num).toDouble();
                    final diff = actual - expected;
                    final at = (checkpoint['at'] as String).substring(0, 16).replaceFirst('T', '  ');
                    return ListTile(
                      leading: Icon(
                        diff == 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        color: diff == 0 ? Colors.green : Colors.orange,
                      ),
                      title: Text('استلمها: ${checkpoint['by_user_name']}'),
                      subtitle: Text(
                        '$at\nمتوقع: ${expected.toStringAsFixed(2)} ج  •  فعلي: ${actual.toStringAsFixed(2)} ج'
                        '${diff != 0 ? '\nفرق: ${diff.toStringAsFixed(2)} ج' : ''}'
                        '${(checkpoint['notes'] != null) ? '\n${checkpoint['notes']}' : ''}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
    );
  }
}
