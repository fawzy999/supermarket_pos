import 'package:flutter/material.dart';
import '../repository/closing_cycle_repository.dart';

/// إعدادات الإقفال الإجباري: كل كام ساعة لازم يحصل إغلاق وردية كامل أو
/// استلام نقدية من الخزنة - وإلا البيع بيتقفل مؤقتًا لغير الأدمن.
class MandatoryClosingSettingsScreen extends StatefulWidget {
  const MandatoryClosingSettingsScreen({super.key});

  @override
  State<MandatoryClosingSettingsScreen> createState() => _MandatoryClosingSettingsScreenState();
}

class _MandatoryClosingSettingsScreenState extends State<MandatoryClosingSettingsScreen> {
  final _repository = ClosingCycleRepository();
  final _hoursController = TextEditingController(text: '24');
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _repository.isEnabled();
    final hours = await _repository.getHours();
    setState(() {
      _enabled = enabled;
      _hoursController.text = hours.toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    var hours = int.tryParse(_hoursController.text) ?? 24;
    if (hours < 1) hours = 1;
    await _repository.setSettings(enabled: _enabled, hours: hours);
    setState(() {
      _hoursController.text = hours.toString();
      _saving = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الإقفال الإجباري')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الإقفال الإجباري')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('تفعيل الإقفال الإجباري'),
            subtitle: const Text('لو متعطّل، البيع مايتقفلش أبدًا حتى لو اتأخر الإقفال'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hoursController,
            enabled: _enabled,
            decoration: const InputDecoration(
              labelText: 'كل كام ساعة لازم يحصل إغلاق وردية أو استلام خزنة',
              suffixText: 'ساعة',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Text(
            'لو عدّت المدة دي من غير إغلاق وردية كامل (تسليم عهدة) أو استلام نقدية من الخزنة، '
            'البيع هيتقفل مؤقتًا لغير الأدمن لحد ما يحصل أي واحدة من الاتنين.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
          ),
        ],
      ),
    );
  }
}
