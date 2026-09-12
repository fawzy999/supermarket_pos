import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../settings/app_settings_repository.dart';

/// نتيجة محاولة التفعيل.
enum LicenseActivationResult { success, invalidCode, codeExpired }

/// حالة الترخيص الحالية للتطبيق.
enum LicenseStatus { notActivated, active, expired, clockTampered }

/// نظام تفعيل البرنامج - يشتغل بالكامل من غير إنترنت (offline).
///
/// الفكرة: كل نسخة مُثبّتة من التطبيق بيتولّد لها "رقم جهاز" عشوائي فريد
/// أول ما تتفتح (مش رقم فعلي للهاردوير - رقم تعريف خاص بالتثبيت ده بس).
/// العميل بيبعت الرقم ده للمطوّر، والمطوّر بيولّد "كود تفعيل" مقابل له
/// باستخدام دالة تشفير (HMAC-SHA256) بمفتاح سري موجود جوه كود التطبيق
/// نفسه - نفس الخوارزمية بالظبط بتستخدم للتوليد وللتحقق.
///
/// كود التفعيل ممكن يحمل جوّه بيانات "تاريخ انتهاء" اختياري (مدة تفعيل
/// محددة يحددها المطوّر وقت التوليد)، أو يكون بدون تاريخ انتهاء (تفعيل
/// دائم). التحقق من الانتهاء بيتم بمقارنة تاريخ اليوم الحالي في جهاز
/// العميل بالتاريخ المُشفّر جوه الكود - ملحوظة مهمة: ده معتمد على ساعة
/// الجهاز نفسه (مفيش سيرفر يتأكد من الوقت الحقيقي)، فلو حد غيّر تاريخ
/// جهازه للخلف بقصد التحايل، النظام بيكتشف الحالة دي (عن طريق تسجيل آخر
/// تاريخ اتفتح بيه البرنامج) ويقفل البرنامج لحد ما يتصلح التاريخ أو
/// يتفعّل بكود جديد.
///
/// ملحوظة أمان: المفتاح السري مُضمّن جوه كود التطبيق (APK) اللي بيوصل
/// للعميل، فمن الناحية النظرية شخص محترف جدًا في الهندسة العكسية ممكن
/// يستخرجه لو فكّك التطبيق - وده قيد معروف وطبيعي في أي نظام تفعيل يشتغل
/// بالكامل من غير سيرفر خارجي. الحل ده مناسب لحماية بيع البرنامج بشكل
/// عملي (منع النسخ العشوائي)، مش حماية عسكرية.
class LicenseService {
  static const _settingsKeyDeviceId = 'license_device_id';
  static const _settingsKeyActivated = 'license_activated';
  static const _settingsKeyActivationCode = 'license_activation_code';
  static const _settingsKeyExpiry = 'license_expiry_iso'; // 'none' أو تاريخ ISO
  static const _settingsKeyLastSeen = 'license_last_seen_iso';

  // المفتاح السري المستخدم في توليد/التحقق من أكواد التفعيل - نفسه بالظبط
  // بيُستخدم في شاشة "توليد كود تفعيل" (لوحة التحكم) وفي التحقق هنا.
  static const _licenseSecret = 'AkPTY7k5WlmZGW5zp7Sm7RpTKpJ3hM7USJER60p8';

  // كلمة سر خاصة بالمطوّر بس - بتفتح شاشة توليد أكواد التفعيل.
  static const developerMasterKey = 'CODEX-DEV-9215';

  // نقطة بداية حساب أيام الانتهاء (أي تاريخ ثابت قبل إصدار البرنامج).
  static final DateTime _epoch = DateTime.utc(2025, 1, 1);

  // قيمة خاصة تعني "بدون تاريخ انتهاء - تفعيل دائم".
  static const int _unlimitedMarker = 0xFFFF;

  // سماحية بسيطة (بالساعات) لفروق ساعة الجهاز الطبيعية (تغيير Time zone
  // مثلاً) قبل ما نعتبرها محاولة تلاعب بالتاريخ.
  static const _clockToleranceHours = 6;

  final _settingsRepository = AppSettingsRepository();

  /// بيرجع رقم الجهاز الحالي - لو مش موجود بيتولّد رقم جديد عشوائي
  /// ويتسجل مرة واحدة بس.
  Future<String> getOrCreateDeviceId() async {
    final existing = await _settingsRepository.get(_settingsKeyDeviceId);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final deviceId = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    await _settingsRepository.set(_settingsKeyDeviceId, deviceId);
    return deviceId;
  }

  String _encodeExpiry(DateTime? expiryDate) {
    if (expiryDate == null) return _unlimitedMarker.toRadixString(16).toUpperCase().padLeft(4, '0');
    final days = expiryDate.toUtc().difference(_epoch).inDays;
    final clamped = days.clamp(0, _unlimitedMarker - 1);
    return clamped.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  DateTime? _decodeExpiry(String expiryHex) {
    final value = int.parse(expiryHex, radix: 16);
    if (value == _unlimitedMarker) return null;
    return _epoch.add(Duration(days: value));
  }

  /// بيحسب كود التفعيل الصحيح لرقم جهاز معيّن، مع تاريخ انتهاء اختياري
  /// (null = تفعيل دائم بدون انتهاء). نفس الدالة دي بتُستخدم للتوليد
  /// (شاشة المطوّر) وللتحقق (بالأسفل).
  String computeActivationCode(String deviceId, {DateTime? expiryDate}) {
    final normalizedDeviceId = deviceId.trim().toUpperCase();
    final expiryHex = _encodeExpiry(expiryDate);
    final hmac = Hmac(sha256, utf8.encode(_licenseSecret));
    final digest = hmac.convert(utf8.encode('$normalizedDeviceId|$expiryHex'));
    final signature = digest.toString().toUpperCase().substring(0, 12);
    final combined = '$expiryHex$signature'; // 4 + 12 = 16 حرف
    return '${combined.substring(0, 4)}-${combined.substring(4, 8)}-${combined.substring(8, 12)}-${combined.substring(12, 16)}';
  }

  String _normalizeCode(String code) {
    return code.trim().toUpperCase().replaceAll(RegExp(r'[^A-F0-9]'), '');
  }

  /// بيتحقق من كود مُدخل مقابل رقم الجهاز الحالي، ولو صح وسليم (ومش منتهي
  /// أصلاً وقت إدخاله) بيسجّل التفعيل.
  Future<LicenseActivationResult> activate(String enteredCode) async {
    final deviceId = await getOrCreateDeviceId();
    final normalized = _normalizeCode(enteredCode);
    if (normalized.length != 16) return LicenseActivationResult.invalidCode;

    final expiryHex = normalized.substring(0, 4);
    final providedSignature = normalized.substring(4, 16);
    final hmac = Hmac(sha256, utf8.encode(_licenseSecret));
    final digest = hmac.convert(utf8.encode('${deviceId.toUpperCase()}|$expiryHex'));
    final expectedSignature = digest.toString().toUpperCase().substring(0, 12);

    if (providedSignature != expectedSignature) return LicenseActivationResult.invalidCode;

    final expiryDate = _decodeExpiry(expiryHex);
    final now = DateTime.now();
    if (expiryDate != null && now.isAfter(expiryDate)) {
      return LicenseActivationResult.codeExpired;
    }

    await _settingsRepository.set(_settingsKeyActivated, '1');
    await _settingsRepository.set(_settingsKeyActivationCode, enteredCode.trim());
    await _settingsRepository.set(_settingsKeyExpiry, expiryDate == null ? 'none' : expiryDate.toIso8601String());
    await _settingsRepository.set(_settingsKeyLastSeen, now.toIso8601String());
    return LicenseActivationResult.success;
  }

  /// بيرجع حالة الترخيص الحالية، وبيحدّث "آخر تاريخ شوهد فيه البرنامج"
  /// عشان يكتشف لو حد رجّع تاريخ الجهاز للخلف بقصد تمديد الصلاحية.
  Future<LicenseStatus> checkStatus() async {
    final activated = await _settingsRepository.get(_settingsKeyActivated);
    if (activated != '1') return LicenseStatus.notActivated;

    final now = DateTime.now();
    final lastSeenStr = await _settingsRepository.get(_settingsKeyLastSeen);
    final lastSeen = lastSeenStr == null ? null : DateTime.tryParse(lastSeenStr);
    if (lastSeen != null && now.isBefore(lastSeen.subtract(const Duration(hours: _clockToleranceHours)))) {
      return LicenseStatus.clockTampered;
    }
    if (lastSeen == null || now.isAfter(lastSeen)) {
      await _settingsRepository.set(_settingsKeyLastSeen, now.toIso8601String());
    }

    final expiryStr = await _settingsRepository.get(_settingsKeyExpiry);
    if (expiryStr == null || expiryStr == 'none') return LicenseStatus.active;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return LicenseStatus.active;
    if (now.isAfter(expiry)) return LicenseStatus.expired;
    return LicenseStatus.active;
  }

  /// بيرجع تاريخ الانتهاء الحالي (null = دائم، أو لو لسه مش مفعّل).
  Future<DateTime?> getCurrentExpiry() async {
    final expiryStr = await _settingsRepository.get(_settingsKeyExpiry);
    if (expiryStr == null || expiryStr == 'none') return null;
    return DateTime.tryParse(expiryStr);
  }
}
