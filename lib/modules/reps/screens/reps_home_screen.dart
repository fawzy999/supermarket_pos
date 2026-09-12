import 'dart:io';
import 'package:flutter/material.dart';
import '../models/rep.dart';
import '../repository/rep_repository.dart';
import 'rep_form_screen.dart';
import 'rep_profile_screen.dart';
import 'reps_performance_screen.dart';

/// الشاشة الرئيسية لموديول "المناديب والشحن": قائمة كل المناديب،
/// إضافة مندوب جديد، والدخول لتقرير أداء عام لكل المناديب.
class RepsHomeScreen extends StatefulWidget {
  const RepsHomeScreen({super.key});

  @override
  State<RepsHomeScreen> createState() => _RepsHomeScreenState();
}

class _RepsHomeScreenState extends State<RepsHomeScreen> {
  final _repository = RepRepository();
  List<Rep> _reps = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final reps = await _repository.getAllReps(searchQuery: _searchQuery);
    setState(() {
      _reps = reps;
      _loading = false;
    });
  }

  Future<void> _addRep() async {
    final newRep = await Navigator.push<Rep>(
      context,
      MaterialPageRoute(builder: (_) => const RepFormScreen()),
    );
    _load();
    // بعد ما يتحفظ المندوب الجديد، ندخل بروفايله على طول عشان يقدر
    // يضيف مستنداته وصورته وباقي بياناته من غير ما يدور عليه في القائمة
    if (newRep != null && mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => RepProfileScreen(rep: newRep)));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المناديب والشحن'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'تقرير أداء المناديب',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RepsPerformanceScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو التليفون',
                prefixIcon: Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _load();
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRep,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('مندوب جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reps.isEmpty
              ? const Center(child: Text('لا يوجد مناديب مسجلين حتى الآن'))
              : ListView.builder(
                  itemCount: _reps.length,
                  itemBuilder: (context, index) {
                    final rep = _reps[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (rep.photoPath != null && File(rep.photoPath!).existsSync())
                            ? FileImage(File(rep.photoPath!)) as ImageProvider
                            : null,
                        child: (rep.photoPath == null || !File(rep.photoPath!).existsSync())
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      title: Text(rep.name),
                      subtitle: Text(rep.phone ?? ''),
                      trailing: !rep.active
                          ? const Chip(label: Text('غير نشط'), visualDensity: VisualDensity.compact)
                          : null,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RepProfileScreen(rep: rep)),
                        );
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}
