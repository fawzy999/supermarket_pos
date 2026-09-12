import '../../settings/app_settings_repository.dart';
import 'shift_repository.dart';
import 'cash_checkpoint_repository.dart';

/// منطق الإقفال الإجباري كل 24 ساعة (المدة قابلة للتعديل من لوحة التحكم):
/// لازم يحصل إما إغلاق وردية كامل بتسليم عهدة مؤكَّد، أو استلام نقدية من
/// الخزنة بواسطة المدير/المحاسب، خلال آخر مدة محددة - وإلا البيع بيتقفل
/// مؤقتًا لغير الأدمن لحد ما يحصل أي واحدة من الاتنين.
class ClosingCycleRepository {
  final _settingsRepository = AppSettingsRepository();
  final _shiftRepository = ShiftRepository();
  final _checkpointRepository = CashCheckpointRepository();

  Future<bool> isEnabled() async {
    final value = await _settingsRepository.get(AppSettingsRepository.keyMandatoryClosingEnabled);
    // مفعّل بشكل افتراضي (زي ما طلب أحمد "عاوزينه إجباري")
    return value == null ? true : value == '1';
  }

  Future<int> getHours() async {
    final value = await _settingsRepository.get(AppSettingsRepository.keyMandatoryClosingHours);
    return int.tryParse(value ?? '') ?? 24;
  }

  Future<void> setSettings({required bool enabled, required int hours}) async {
    await _settingsRepository.set(AppSettingsRepository.keyMandatoryClosingEnabled, enabled ? '1' : '0');
    await _settingsRepository.set(AppSettingsRepository.keyMandatoryClosingHours, hours.toString());
  }

  /// آخر لحظة اتسجل فيها إقفال رسمي (تسليم عهدة مؤكَّد أو استلام نقدية) -
  /// لو مفيش أي حاجة اتسجلت خالص، بيرجّع وقت أول وردية على الإطلاق كنقطة بداية
  Future<DateTime?> getLastClosureTime() async {
    final lastConfirmed = await _shiftRepository.getLastConfirmedClosureTime();
    final lastCheckpoint = await _checkpointRepository.getLastCheckpointTime();
    DateTime? latest;
    for (final candidate in [lastConfirmed, lastCheckpoint]) {
      if (candidate == null) continue;
      if (latest == null || candidate.isAfter(latest)) latest = candidate;
    }
    if (latest != null) return latest;
    return _shiftRepository.getEarliestShiftTime();
  }

  /// هل الوقت المسموح خلص من غير أي إقفال/استلام؟
  Future<bool> isOverdue() async {
    if (!await isEnabled()) return false;
    final lastClosure = await getLastClosureTime();
    if (lastClosure == null) return false; // مفيش أي وردية اتسجلت خالص لسه
    final hours = await getHours();
    return DateTime.now().difference(lastClosure).inHours >= hours;
  }

  /// الوقت المتبقي قبل ما الإقفال يبقى إجباري (null لو معطّل أو مش معروف)
  Future<Duration?> getTimeRemaining() async {
    if (!await isEnabled()) return null;
    final lastClosure = await getLastClosureTime();
    if (lastClosure == null) return null;
    final hours = await getHours();
    final deadline = lastClosure.add(Duration(hours: hours));
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
