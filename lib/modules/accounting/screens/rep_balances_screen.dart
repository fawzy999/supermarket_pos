import 'package:flutter/material.dart';
import '../../reps/repository/rep_repository.dart';
import '../../reps/screens/rep_account_screen.dart';

/// كل المناديب اللي عليهم بضاعة تحت العهدة أو مديونية نقدية، مرتبين من
/// الأكبر للأصغر، مع رابط مباشر لحساب كل مندوب.
class RepBalancesScreen extends StatefulWidget {
  const RepBalancesScreen({super.key});

  @override
  State<RepBalancesScreen> createState() => _RepBalancesScreenState();
}

class _RepBalancesScreenState extends State<RepBalancesScreen> {
  final _repRepository = RepRepository();
  List<Map<String, dynamic>> _summaries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summaries = await _repRepository.getAllRepsAccountSummaries();
    setState(() {
      _summaries = summaries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalCustody = _summaries.fold<double>(0, (sum, r) => sum + (r['custody_value'] as double));
    final totalCash = _summaries.fold<double>(0, (sum, r) => sum + (r['cash_owed'] as double));

    return Scaffold(
      appBar: AppBar(title: const Text('أرصدة المناديب')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row('إجمالي قيمة البضاعة تحت العهدة', totalCustody),
                          _row('إجمالي المديونية النقدية', totalCash),
                          const Divider(),
                          _row('الإجمالي الكلي المستحق', totalCustody + totalCash, highlight: true),
                        ],
                      ),
                    ),
                  ),
                  if (_summaries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لا يوجد مناديب عليهم بضاعة أو مديونية حاليًا'),
                    )
                  else
                    ..._summaries.map((row) => ListTile(
                          leading: const Icon(Icons.delivery_dining_outlined),
                          title: Text(row['rep_name'] as String),
                          subtitle: Text(
                            'بضاعة: ${(row['custody_value'] as double).toStringAsFixed(2)} ج'
                            '  •  مديونية نقدية: ${(row['cash_owed'] as double).toStringAsFixed(2)} ج',
                          ),
                          trailing: Text(
                            '${(row['total_due'] as double).toStringAsFixed(2)} ج',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            final reps = await _repRepository.getAllReps();
                            final rep = reps.firstWhere((r) => r.id == row['rep_id']);
                            if (!mounted) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RepAccountScreen(rep: rep)),
                            );
                            _load();
                          },
                        )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _row(String label, double value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
          Text(
            '${value.toStringAsFixed(2)} ج',
            style: TextStyle(fontWeight: highlight ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
