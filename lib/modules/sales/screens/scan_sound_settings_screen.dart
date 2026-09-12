import 'package:flutter/material.dart';
import '../../../core/settings/app_settings_repository.dart';
import '../../../core/services/scan_sound_service.dart';

/// إعدادات صوت الباركود: تفعيل/تعطيل صوت النجاح والفشل في شاشة البيع،
/// والتحكم في مستوى الصوت - مع زرار تجربة سريع يشغّل الصوتين فورًا.
class ScanSoundSettingsScreen extends StatefulWidget {
  const ScanSoundSettingsScreen({super.key});

  @override
  State<ScanSoundSettingsScreen> createState() => _ScanSoundSettingsScreenState();
}

class _ScanSoundSettingsScreenState extends State<ScanSoundSettingsScreen> {
  final _repository = AppSettingsRepository();
  final _scanSoundService = ScanSoundService();
  bool _enabled = true;
  double _volume = 0.8;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.getAll([
      AppSettingsRepository.keyScanSoundEnabled,
      AppSettingsRepository.keyScanSoundVolume,
    ]);
    setState(() {
      _enabled = (settings[AppSettingsRepository.keyScanSoundEnabled] ?? '1') == '1';
      _volume = double.tryParse(settings[AppSettingsRepository.keyScanSoundVolume] ?? '') ?? 0.8;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _repository.set(AppSettingsRepository.keyScanSoundEnabled, _enabled ? '1' : '0');
    await _repository.set(AppSettingsRepository.keyScanSoundVolume, _volume.toString());
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الصوت')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات صوت الباركود')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('تفعيل صوت الباركود'),
            subtitle: const Text('بيب نجاح لما الصنف يتلاقى، وصوت تنبيه مختلف لو الباركود مش معروف'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 16),
          Text('مستوى الصوت', style: TextStyle(color: Colors.grey.shade700)),
          Slider(
            value: _volume,
            onChanged: _enabled ? (v) => setState(() => _volume = v) : null,
            divisions: 10,
            label: '${(_volume * 100).round()}%',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _enabled
                      ? () async {
                          await _repository.set(AppSettingsRepository.keyScanSoundEnabled, '1');
                          await _repository.set(AppSettingsRepository.keyScanSoundVolume, _volume.toString());
                          _scanSoundService.playSuccess();
                        }
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('تجربة صوت النجاح'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _enabled
                      ? () async {
                          await _repository.set(AppSettingsRepository.keyScanSoundEnabled, '1');
                          await _repository.set(AppSettingsRepository.keyScanSoundVolume, _volume.toString());
                          _scanSoundService.playError();
                        }
                      : null,
                  icon: const Icon(Icons.error_outline),
                  label: const Text('تجربة صوت الفشل'),
                ),
              ),
            ],
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
