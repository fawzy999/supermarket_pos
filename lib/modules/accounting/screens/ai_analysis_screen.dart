import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/settings/app_settings_repository.dart';
import '../../../core/services/ai_service.dart';
import '../repository/accounting_repository.dart';

/// تحليل ذكي لأرقام المبيعات باستخدام Claude API - يطلب مفتاح API
/// من الأدمن (بيتخزن محليًا فقط)، يجمع أرقام آخر ٣٠ يوم، ويرسلها
/// للتحليل، ويعرض رد نصي بالعربي فيه ملاحظات واقتراحات عملية.
class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({super.key});

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  final _accountingRepository = AccountingRepository();
  final _settingsRepository = AppSettingsRepository();
  final _aiService = AiService();

  bool _loading = false;
  String? _result;
  String? _error;

  Future<void> _openSettings() async {
    final currentKey = await _settingsRepository.get(AppSettingsRepository.keyAiApiKey) ?? '';
    final currentModel = await _settingsRepository.get(AppSettingsRepository.keyAiModel) ?? '';
    final keyController = TextEditingController(text: currentKey);
    final modelController = TextEditingController(text: currentModel);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات الذكاء الاصطناعي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(labelText: 'مفتاح Anthropic API Key'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(labelText: 'اسم الموديل (اختياري - سيب فاضي للافتراضي)'),
            ),
            const SizedBox(height: 8),
            const Text(
              'المفتاح بيتخزن على جهازك فقط وبيتبعت مباشرة لـ Anthropic عند التحليل.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );

    if (confirmed != true) return;
    await _settingsRepository.set(AppSettingsRepository.keyAiApiKey, keyController.text.trim());
    await _settingsRepository.set(AppSettingsRepository.keyAiModel, modelController.text.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اتحفظت الإعدادات')));
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final apiKey = await _settingsRepository.get(AppSettingsRepository.keyAiApiKey) ?? '';
      final model = await _settingsRepository.get(AppSettingsRepository.keyAiModel);

      final monthStart = AccountingRepository.startOfMonth();
      final todayStart = AccountingRepository.startOfToday();
      final monthRevenue = await _accountingRepository.getRevenue(sinceDate: monthStart);
      final monthProfit = await _accountingRepository.getProfit(sinceDate: monthStart);
      final monthExpenses = await _accountingRepository.getTotalExpenses(sinceDate: monthStart);
      final todayRevenue = await _accountingRepository.getRevenue(sinceDate: todayStart);
      final cashierRevenue = await _accountingRepository.getRevenueByCashier(sinceDate: monthStart);

      final summary = StringBuffer()
        ..writeln('مبيعات اليوم: ${todayRevenue.toStringAsFixed(2)} ج')
        ..writeln('مبيعات الشهر: ${monthRevenue.toStringAsFixed(2)} ج')
        ..writeln('ربح الشهر: ${monthProfit.toStringAsFixed(2)} ج')
        ..writeln('مصروفات الشهر: ${monthExpenses.toStringAsFixed(2)} ج')
        ..writeln('صافي ربح الشهر: ${(monthProfit - monthExpenses).toStringAsFixed(2)} ج');
      if (cashierRevenue.isNotEmpty) {
        summary.writeln('مبيعات كل كاشير هذا الشهر:');
        for (final row in cashierRevenue) {
          summary.writeln('- ${row['cashier_name']}: ${(row['total'] as num).toStringAsFixed(2)} ج');
        }
      }

      final analysis = await _aiService.analyzeSalesData(
        apiKey: apiKey,
        dataSummary: summary.toString(),
        model: model,
      );
      setState(() => _result = analysis);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحليل ذكي بالـ AI'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'إعدادات', onPressed: _openSettings),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('حلّل مبيعات الشهر الحالي'),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ),
            if (_result != null)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: SingleChildScrollView(child: Text(_result!))),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => Share.share(_result!),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('مشاركة التحليل'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
