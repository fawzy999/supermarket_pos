import 'package:flutter/material.dart';
import '../../modules_registry/module_registry.dart';
import '../../modules_registry/module_repository.dart';

/// تفعيل/تعطيل أي موديول تشغيليًا (المخزون، المبيعات، الموظفين...)
/// من غير ما تلمس كود - الموديول المعطّل بيختفي فورًا من الشاشة
/// الرئيسية لكل المستخدمين. الترخيص نفسه (is_licensed) بيتحكم فيه
/// مفتاح التفعيل مستقبلًا ومش متاح للتعديل من هنا.
class ModulesToggleScreen extends StatefulWidget {
  const ModulesToggleScreen({super.key});

  @override
  State<ModulesToggleScreen> createState() => _ModulesToggleScreenState();
}

class _ModulesToggleScreenState extends State<ModulesToggleScreen> {
  final _repository = ModuleRepository();
  Map<String, Map<String, bool>> _status = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final status = await _repository.getAllModulesStatus();
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  Future<void> _toggle(String moduleKey, bool enabled) async {
    await _repository.setModuleEnabled(moduleKey, enabled);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل/تعطيل الموديولات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: ModuleRegistry.all.length,
              itemBuilder: (context, index) {
                final module = ModuleRegistry.all[index];
                final status = _status[module.key];
                final licensed = status?['is_licensed'] ?? false;
                final enabled = status?['is_enabled'] ?? false;

                return SwitchListTile(
                  secondary: Icon(module.icon),
                  title: Text(module.nameAr),
                  subtitle: Text(licensed ? 'مرخّص لحسابك' : 'غير مرخّص لحسابك حاليًا'),
                  value: enabled,
                  onChanged: licensed ? (v) => _toggle(module.key, v) : null,
                );
              },
            ),
    );
  }
}
