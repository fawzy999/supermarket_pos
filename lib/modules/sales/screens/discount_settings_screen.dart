import 'package:flutter/material.dart';
import '../../../core/settings/app_settings_repository.dart';

/// إعدادات الخصم: تفعيل/تعطيل إمكانية الخصم في نقطة البيع، وتحديد أقصى
/// نسبة خصم مسموح للكاشير يطبّقها بنفسه من غير إذن كل مرة.
class DiscountSettingsScreen extends StatefulWidget {
  const DiscountSettingsScreen({super.key});

  @override
  State<DiscountSettingsScreen> createState() => _DiscountSettingsScreenState();
}

class _DiscountSettingsScreenState extends State<DiscountSettingsScreen> {
  final _repository = AppSettingsRepository();
  final _maxDiscountController = TextEditingController(text: '10');
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.getAll([
      AppSettingsRepository.keyDiscountEnabled,
      AppSettingsRepository.keyMaxDiscountPercent,
    ]);
    setState(() {
      _enabled = settings[AppSettingsRepository.keyDiscountEnabled] == '1';
      _maxDiscountController.text = settings[AppSettingsRepository.keyMaxDiscountPercent] ?? '10';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    var maxDiscount = double.tryParse(_maxDiscountController.text) ?? 10;
    if (maxDiscount < 1) maxDiscount = 1;
    if (maxDiscount > 10) maxDiscount = 10;
    await _repository.set(AppSettingsRepository.keyDiscountEnabled, _enabled ? '1' : '0');
    await _repository.set(AppSettingsRepository.keyMaxDiscountPercent, maxDiscount.toString());
    setState(() {
      _maxDiscountController.text = maxDiscount.toString();
      _saving = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الخصم')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الخصم')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('تفعيل الخصم في نقطة البيع'),
            subtitle: const Text('لو متعطّل، زرار الخصم في شاشة البيع مش هيشتغل'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxDiscountController,
            enabled: _enabled,
            decoration: const InputDecoration(
              labelText: 'أقصى نسبة خصم مسموحة (من 1% إلى 10%)',
              suffixText: '%',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          Text(
            'الكاشير هيقدر يطبّق أي نسبة خصم من صفر لحد الحد الأقصى ده بنفسه من غير ما يرجعلك - '
            'اضبطها على القيمة إلى إنت مرتاح لها.',
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
