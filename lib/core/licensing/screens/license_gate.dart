import 'package:flutter/material.dart';
import '../license_service.dart';
import 'activation_screen.dart';
import '../../auth/screens/login_screen.dart';

/// البوابة الأولى اللي بتفتح مع التطبيق: بتتأكد إن البرنامج مفعّل ومدة
/// التفعيل لسه سارية قبل ما تسمح بالدخول لشاشة تسجيل الدخول العادية.
/// لو مش مفعّل، أو انتهت مدة التفعيل، أو لو حصل تلاعب في تاريخ الجهاز،
/// بتوقف عند شاشة التفعيل ومش بتسمح بأي استخدام تاني للبرنامج.
class LicenseGate extends StatefulWidget {
  const LicenseGate({super.key});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  final _licenseService = LicenseService();
  bool _loading = true;
  LicenseStatus _status = LicenseStatus.notActivated;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final status = await _licenseService.checkStatus();
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_status == LicenseStatus.active) {
      return const LoginScreen();
    }
    return ActivationScreen(
      status: _status,
      onActivated: () => setState(() => _status = LicenseStatus.active),
    );
  }
}
