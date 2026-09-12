import 'package:local_auth/local_auth.dart';

/// تغليف بسيط لمكتبة local_auth - التطبيق مش بيخزن أي بصمة فعلية، بس بيسأل
/// نظام الأندرويد نفسه "البصمة اللي اتحطت دلوقتي صح ولا لأ" (رمز أمان
/// مشفّر من الجهاز، مش بيانات بصمة خام).
class BiometricService {
  final _auth = LocalAuthentication();

  /// هل الجهاز نفسه بيدعم بصمة/فتح بالوجه أصلًا ومتاح دلوقتي؟
  Future<bool> isDeviceSupported() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// بيطلب من الجهاز التحقق بالبصمة - بيرجع true لو نجح
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'أكّد هويتك بالبصمة لتسجيل الدخول',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
