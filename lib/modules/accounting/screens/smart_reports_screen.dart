import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/settings/app_settings_repository.dart';
import '../../../core/services/email_service.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../core/store_settings/store_settings_repository.dart';
import '../repository/accounting_repository.dart';

/// تقارير دورية (يومي/أسبوعي/شهري) بتتبعت لمدير المحل على واتساب
/// أو إيميل بضغطة واحدة. الإرسال يدوي (بتضغط "إرسال دلوقتي") - مش
/// جدولة تلقائية بالكامل، لأن ده محتاج سيرفر أو خدمة خلفية شغالة
/// حتى لو الموبايل مقفول، وده خارج نطاق تطبيق موبايل عادي حاليًا.
class SmartReportsScreen extends StatefulWidget {
  const SmartReportsScreen({super.key});

  @override
  State<SmartReportsScreen> createState() => _SmartReportsScreenState();
}

class _SmartReportsScreenState extends State<SmartReportsScreen> {
  final _accountingRepository = AccountingRepository();
  final _storeRepository = StoreSettingsRepository();
  final _settingsRepository = AppSettingsRepository();
  final _emailService = EmailService();

  String _period = 'day'; // day / week / month
  bool _sending = false;

  Future<String> _buildReportText() async {
    final now = DateTime.now();
    final String sinceDate;
    final String periodLabel;
    final String previousStart;
    final String previousEnd;
    switch (_period) {
      case 'week':
        sinceDate = AccountingRepository.startOfWeek();
        periodLabel = 'الأسبوعي';
        final start = DateTime.parse(sinceDate);
        previousStart = start.subtract(const Duration(days: 7)).toIso8601String();
        previousEnd = sinceDate;
        break;
      case 'month':
        sinceDate = AccountingRepository.startOfMonth();
        periodLabel = 'الشهري';
        final start = DateTime.parse(sinceDate);
        final prevMonthStart = DateTime(start.year, start.month - 1, 1);
        previousStart = prevMonthStart.toIso8601String();
        previousEnd = sinceDate;
        break;
      default:
        sinceDate = AccountingRepository.startOfToday();
        periodLabel = 'اليومي';
        final start = DateTime.parse(sinceDate);
        previousStart = start.subtract(const Duration(days: 1)).toIso8601String();
        previousEnd = sinceDate;
    }

    final revenue = await _accountingRepository.getRevenue(sinceDate: sinceDate);
    final profit = await _accountingRepository.getProfit(sinceDate: sinceDate);
    final expenses = await _accountingRepository.getTotalExpenses(sinceDate: sinceDate);
    final previousRevenue = await _accountingRepository.getRevenueBetween(start: previousStart, end: previousEnd);
    final storeSettings = await _storeRepository.getSettings();
    final storeName = storeSettings['store_name'] ?? 'سوبر ماركت Codex';
    final net = profit - expenses;

    String comparisonLine;
    if (previousRevenue > 0) {
      final changePercent = ((revenue - previousRevenue) / previousRevenue) * 100;
      final direction = changePercent >= 0 ? 'زادت' : 'قلت';
      comparisonLine = 'المبيعات $direction ${changePercent.abs().toStringAsFixed(1)}% عن الفترة السابقة '
          '(${previousRevenue.toStringAsFixed(2)} ج)';
    } else {
      comparisonLine = 'لا توجد مبيعات مسجلة في الفترة السابقة للمقارنة';
    }

    return '''
تقرير $periodLabel - $storeName
التاريخ: ${now.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}

إجمالي المبيعات: ${revenue.toStringAsFixed(2)} ج
إجمالي الربح: ${profit.toStringAsFixed(2)} ج
إجمالي المصروفات: ${expenses.toStringAsFixed(2)} ج
صافي الربح: ${net.toStringAsFixed(2)} ج

$comparisonLine
'''
        .trim();
  }

  Future<void> _sendWhatsApp() async {
    setState(() => _sending = true);
    try {
      final phone = await _settingsRepository.get(AppSettingsRepository.keyManagerPhone);
      if (phone == null || phone.trim().isEmpty) {
        if (mounted) _showError('حط رقم واتساب المدير الأول من إعدادات هذه الشاشة (أيقونة الإعدادات فوق)');
        return;
      }
      final text = await _buildReportText();
      final opened = await WhatsAppHelper.openChat(phone: phone, text: text);
      if (!opened && mounted) _showError('مقدرناش نفتح واتساب - تأكد إنه متثبت على الجهاز');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendEmail() async {
    setState(() => _sending = true);
    try {
      final settings = await _settingsRepository.getAll([
        AppSettingsRepository.keyManagerEmail,
        AppSettingsRepository.keySmtpHost,
        AppSettingsRepository.keySmtpPort,
        AppSettingsRepository.keySmtpUsername,
        AppSettingsRepository.keySmtpPassword,
      ]);
      final to = settings[AppSettingsRepository.keyManagerEmail];
      final host = settings[AppSettingsRepository.keySmtpHost];
      final port = settings[AppSettingsRepository.keySmtpPort];
      final username = settings[AppSettingsRepository.keySmtpUsername];
      final password = settings[AppSettingsRepository.keySmtpPassword];

      if (to == null || to.trim().isEmpty || host == null || host.trim().isEmpty ||
          username == null || username.trim().isEmpty || password == null || password.trim().isEmpty) {
        if (mounted) _showError('لازم تكمّل إعدادات الإيميل و SMTP الأول (أيقونة الإعدادات فوق)');
        return;
      }

      final text = await _buildReportText();
      await _emailService.send(
        host: host.trim(),
        port: int.tryParse(port ?? '') ?? 465,
        username: username.trim(),
        password: password,
        to: to.trim(),
        subject: 'تقرير المحل',
        body: text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اتبعت الإيميل بنجاح')));
      }
    } catch (e) {
      if (mounted) _showError('حصل خطأ في إرسال الإيميل: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _shareText() async {
    final text = await _buildReportText();
    await Share.share(text);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSettings() async {
    final current = await _settingsRepository.getAll([
      AppSettingsRepository.keyManagerName,
      AppSettingsRepository.keyManagerPhone,
      AppSettingsRepository.keyManagerEmail,
      AppSettingsRepository.keySmtpHost,
      AppSettingsRepository.keySmtpPort,
      AppSettingsRepository.keySmtpUsername,
      AppSettingsRepository.keySmtpPassword,
    ]);

    final nameController = TextEditingController(text: current[AppSettingsRepository.keyManagerName] ?? '');
    final phoneController = TextEditingController(text: current[AppSettingsRepository.keyManagerPhone] ?? '');
    final emailController = TextEditingController(text: current[AppSettingsRepository.keyManagerEmail] ?? '');
    final hostController = TextEditingController(text: current[AppSettingsRepository.keySmtpHost] ?? '');
    final portController = TextEditingController(text: current[AppSettingsRepository.keySmtpPort] ?? '465');
    final usernameController = TextEditingController(text: current[AppSettingsRepository.keySmtpUsername] ?? '');
    final passwordController = TextEditingController(text: current[AppSettingsRepository.keySmtpPassword] ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات التقارير الذكية'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('بيانات المدير', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المدير')),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'رقم واتساب المدير'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'إيميل المدير'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const Text('إعدادات SMTP (لإرسال الإيميل)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: hostController, decoration: const InputDecoration(labelText: 'SMTP Host (مثلاً smtp.gmail.com)')),
              TextField(
                controller: portController,
                decoration: const InputDecoration(labelText: 'SMTP Port (465 غالبًا)'),
                keyboardType: TextInputType.number,
              ),
              TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'إيميل الإرسال (Username)')),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'كلمة السر / App Password'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );

    if (confirmed != true) return;

    await _settingsRepository.set(AppSettingsRepository.keyManagerName, nameController.text.trim());
    await _settingsRepository.set(AppSettingsRepository.keyManagerPhone, phoneController.text.trim());
    await _settingsRepository.set(AppSettingsRepository.keyManagerEmail, emailController.text.trim());
    await _settingsRepository.set(AppSettingsRepository.keySmtpHost, hostController.text.trim());
    await _settingsRepository.set(AppSettingsRepository.keySmtpPort, portController.text.trim());
    await _settingsRepository.set(AppSettingsRepository.keySmtpUsername, usernameController.text.trim());
    await _settingsRepository.set(AppSettingsRepository.keySmtpPassword, passwordController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اتحفظت الإعدادات')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير الذكية'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'إعدادات', onPressed: _openSettings),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر فترة التقرير', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'day', label: Text('اليوم')),
                ButtonSegment(value: 'week', label: Text('الأسبوع')),
                ButtonSegment(value: 'month', label: Text('الشهر')),
              ],
              selected: {_period},
              onSelectionChanged: (selection) => setState(() => _period = selection.first),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sending ? null : _sendWhatsApp,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('إرسال للمدير على واتساب'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sending ? null : _sendEmail,
              icon: const Icon(Icons.email_outlined),
              label: const Text('إرسال للمدير بالإيميل'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _sending ? null : _shareText,
              icon: const Icon(Icons.share_outlined),
              label: const Text('مشاركة التقرير بأي طريقة تانية'),
            ),
            if (_sending) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 24),
            const Text(
              'ملحوظة: الإرسال هنا يدوي - محتاج تفتح التطبيق وتضغط الزرار. الإرسال '
              'التلقائي بالكامل (حتى لو التطبيق مقفول) محتاج خدمة تشتغل في الخلفية '
              'وده تطوير مستقبلي مقترح.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
