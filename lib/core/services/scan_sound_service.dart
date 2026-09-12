import 'package:audioplayers/audioplayers.dart';
import '../settings/app_settings_repository.dart';

/// صوت نجاح/فشل قراءة الباركود في شاشة البيع (زي ماسحات السوبر ماركت
/// العادية) - قابل للتفعيل/التعطيل والتحكم في مستوى الصوت من لوحة
/// تحكم الأدمن (إعدادات صوت الباركود). القيم بتُقرأ من قاعدة البيانات
/// في كل مرة عشان أي تغيير في الإعدادات ينعكس فورًا من غير إعادة فتح
/// شاشة البيع.
class ScanSoundService {
  static final ScanSoundService _instance = ScanSoundService._internal();
  factory ScanSoundService() => _instance;
  ScanSoundService._internal();

  final _settingsRepository = AppSettingsRepository();
  final _successPlayer = AudioPlayer();
  final _errorPlayer = AudioPlayer();

  Future<void> playSuccess() => _play(_successPlayer, 'sounds/scan_success.wav');

  Future<void> playError() => _play(_errorPlayer, 'sounds/scan_error.wav');

  Future<void> _play(AudioPlayer player, String assetPath) async {
    final settings = await _settingsRepository.getAll([
      AppSettingsRepository.keyScanSoundEnabled,
      AppSettingsRepository.keyScanSoundVolume,
    ]);
    // مفعّل بشكل افتراضي (زي أي سوبر ماركت) لو مفيش قيمة محفوظة أصلًا
    final enabled = (settings[AppSettingsRepository.keyScanSoundEnabled] ?? '1') == '1';
    if (!enabled) return;
    final volume = double.tryParse(settings[AppSettingsRepository.keyScanSoundVolume] ?? '') ?? 0.8;
    try {
      await player.stop();
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // أي خطأ في تشغيل الصوت (جهاز بدون سماعة شغالة مثلًا) لازم ما يوقفش
      // عملية البيع نفسها - الصوت تحسين بس، مش جزء أساسي من العملية
    }
  }
}
