import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../license_service.dart';

/// شاشة خاصة بالمطوّر بس: بتاخد "رقم جهاز" عميل (اللي بيبعته من شاشة
/// التفعيل عنده) وبتولّد كود التفعيل المقابل له فورًا، بدون أي إنترنت
/// وبدون أي أداة خارجية - نفس خوارزمية التحقق بالظبط، بس هنا بتُستخدم
/// للتوليد. المطوّر يقدر كمان يحدد "مدة تفعيل" (30/90/180/365 يوم) أو
/// يسيبها "بدون تاريخ انتهاء" لتفعيل دائم. الوصول للشاشة دي محمي بكلمة
/// سر المطوّر في الشاشة اللي قبلها (LicenseGeneratorGateScreen).
class LicenseGeneratorScreen extends StatefulWidget {
  const LicenseGeneratorScreen({super.key});

  @override
  State<LicenseGeneratorScreen> createState() => _LicenseGeneratorScreenState();
}

enum _DurationOption { unlimited, days30, days90, days180, days365, custom }

class _LicenseGeneratorScreenState extends State<LicenseGeneratorScreen> {
  final _licenseService = LicenseService();
  final _deviceIdController = TextEditingController();
  _DurationOption _duration = _DurationOption.unlimited;
  DateTime? _customDate;
  String? _generatedCode;
  DateTime? _generatedExpiry;

  DateTime? get _resolvedExpiry {
    switch (_duration) {
      case _DurationOption.unlimited:
        return null;
      case _DurationOption.days30:
        return DateTime.now().add(const Duration(days: 30));
      case _DurationOption.days90:
        return DateTime.now().add(const Duration(days: 90));
      case _DurationOption.days180:
        return DateTime.now().add(const Duration(days: 180));
      case _DurationOption.days365:
        return DateTime.now().add(const Duration(days: 365));
      case _DurationOption.custom:
        return _customDate;
    }
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _customDate = picked);
  }

  void _generate() {
    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) return;
    if (_duration == _DurationOption.custom && _customDate == null) return;
    final expiry = _resolvedExpiry;
    setState(() {
      _generatedCode = _licenseService.computeActivationCode(deviceId, expiryDate: expiry);
      _generatedExpiry = expiry;
    });
  }

  Future<void> _copyCode() async {
    if (_generatedCode == null) return;
    await Clipboard.setData(ClipboardData(text: _generatedCode!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ كود التفعيل')));
    }
  }

  String _formatDate(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('توليد كود تفعيل (للمطوّر)')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('الصق رقم الجهاز اللي بعتهولك العميل من شاشة التفعيل:'),
              const SizedBox(height: 8),
              TextField(
                controller: _deviceIdController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'رقم الجهاز'),
              ),
              const SizedBox(height: 20),
              const Text('مدة التفعيل:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              RadioListTile<_DurationOption>(
                contentPadding: EdgeInsets.zero,
                title: const Text('بدون تاريخ انتهاء (تفعيل دائم)'),
                value: _DurationOption.unlimited,
                groupValue: _duration,
                onChanged: (v) => setState(() => _duration = v!),
              ),
              RadioListTile<_DurationOption>(
                contentPadding: EdgeInsets.zero,
                title: const Text('30 يوم'),
                value: _DurationOption.days30,
                groupValue: _duration,
                onChanged: (v) => setState(() => _duration = v!),
              ),
              RadioListTile<_DurationOption>(
                contentPadding: EdgeInsets.zero,
                title: const Text('90 يوم'),
                value: _DurationOption.days90,
                groupValue: _duration,
                onChanged: (v) => setState(() => _duration = v!),
              ),
              RadioListTile<_DurationOption>(
                contentPadding: EdgeInsets.zero,
                title: const Text('180 يوم'),
                value: _DurationOption.days180,
                groupValue: _duration,
                onChanged: (v) => setState(() => _duration = v!),
              ),
              RadioListTile<_DurationOption>(
                contentPadding: EdgeInsets.zero,
                title: const Text('365 يوم (سنة)'),
                value: _DurationOption.days365,
                groupValue: _duration,
                onChanged: (v) => setState(() => _duration = v!),
              ),
              RadioListTile<_DurationOption>(
                contentPadding: EdgeInsets.zero,
                title: Text(_customDate == null ? 'تاريخ محدد...' : 'تاريخ محدد: ${_formatDate(_customDate!)}'),
                value: _DurationOption.custom,
                groupValue: _duration,
                onChanged: (v) {
                  setState(() => _duration = v!);
                  _pickCustomDate();
                },
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: _generate, child: const Text('توليد كود التفعيل')),
              if (_generatedCode != null) ...[
                const SizedBox(height: 24),
                const Text('كود التفعيل - ابعته للعميل:'),
                const SizedBox(height: 8),
                Card(
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _generatedCode!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.copy_outlined), onPressed: _copyCode),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _generatedExpiry == null
                              ? 'تفعيل دائم - بدون تاريخ انتهاء'
                              : 'ساري لحد تاريخ: ${_formatDate(_generatedExpiry!)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// بوابة دخول بكلمة سر المطوّر قبل شاشة التوليد - عشان محدش يقدر يوصل
/// للأداة دي غير المطوّر نفسه حتى لو دخل لوحة تحكم الأدمن بتاعت المحل.
class LicenseGeneratorGateScreen extends StatefulWidget {
  const LicenseGeneratorGateScreen({super.key});

  @override
  State<LicenseGeneratorGateScreen> createState() => _LicenseGeneratorGateScreenState();
}

class _LicenseGeneratorGateScreenState extends State<LicenseGeneratorGateScreen> {
  final _keyController = TextEditingController();
  String? _error;

  void _submit() {
    if (_keyController.text.trim() == LicenseService.developerMasterKey) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LicenseGeneratorScreen()),
      );
    } else {
      setState(() => _error = 'كلمة السر غير صحيحة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أداة المطوّر')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('كلمة سر المطوّر:'),
              const SizedBox(height: 8),
              TextField(
                controller: _keyController,
                obscureText: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _submit, child: const Text('دخول')),
            ],
          ),
        ),
      ),
    );
  }
}
