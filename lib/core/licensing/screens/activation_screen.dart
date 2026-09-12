import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../license_service.dart';

/// شاشة تفعيل البرنامج - بتظهر إجباريًا لحد ما العميل يدخل كود تفعيل
/// صحيح وسارٍ. بتعرض "رقم الجهاز" الخاص بالتثبيت ده عشان العميل يبعته
/// للمطوّر ويستلم منه الكود المقابل له. بتتغيّر الرسالة المعروضة حسب
/// السبب اللي وقف البرنامج عنده (مش مفعّل من الأساس / انتهت المدة /
/// تلاعب مكتشف في تاريخ الجهاز).
class ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated;
  final LicenseStatus status;
  const ActivationScreen({super.key, required this.onActivated, this.status = LicenseStatus.notActivated});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _licenseService = LicenseService();
  final _codeController = TextEditingController();
  String? _deviceId;
  bool _loading = true;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final deviceId = await _licenseService.getOrCreateDeviceId();
    setState(() {
      _deviceId = deviceId;
      _loading = false;
    });
  }

  Future<void> _copyDeviceId() async {
    if (_deviceId == null) return;
    await Clipboard.setData(ClipboardData(text: _deviceId!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رقم الجهاز')));
    }
  }

  Future<void> _activate() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _error = 'اكتب كود التفعيل الأول');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    final result = await _licenseService.activate(_codeController.text);
    setState(() => _checking = false);
    switch (result) {
      case LicenseActivationResult.success:
        widget.onActivated();
        break;
      case LicenseActivationResult.invalidCode:
        setState(() => _error = 'كود التفعيل غير صحيح - تأكد إنه مطابق للي استلمته بالظبط');
        break;
      case LicenseActivationResult.codeExpired:
        setState(() => _error = 'الكود ده انتهت صلاحيته - لازم تطلب كود تفعيل جديد');
        break;
    }
  }

  String get _headerMessage {
    switch (widget.status) {
      case LicenseStatus.expired:
        return 'انتهت مدة تفعيل البرنامج - محتاج كود تفعيل جديد للاستمرار';
      case LicenseStatus.clockTampered:
        return 'تم اكتشاف تغيير في تاريخ الجهاز - تأكد إن التاريخ والوقت صحيحين، أو تواصل مع الدعم';
      case LicenseStatus.notActivated:
      case LicenseStatus.active:
        return 'البرنامج محتاج تفعيل قبل ما تقدر تستخدمه';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل البرنامج')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                widget.status == LicenseStatus.expired || widget.status == LicenseStatus.clockTampered
                    ? Icons.event_busy_outlined
                    : Icons.lock_outline,
                size: 56,
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              Text(
                _headerMessage,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text('رقم الجهاز بتاعك - ابعته للدعم الفني عشان تستلم كود التفعيل:'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _deviceId ?? '',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.copy_outlined), onPressed: _copyDeviceId),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('اكتب كود التفعيل اللي استلمته:'),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 1.5),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'XXXX-XXXX-XXXX-XXXX',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _checking ? null : _activate,
                child: Text(_checking ? 'جاري التحقق...' : 'تفعيل'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
