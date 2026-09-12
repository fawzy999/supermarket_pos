import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/offer.dart';
import '../repository/marketing_repository.dart';

/// شاشة العروض التسويقية: تضيف عرض (عنوان + وصف + صورة اختيارية)
/// وتشاركه على واتساب أو أي منصة سوشيال ميديا تانية بضغطة واحدة -
/// بيستخدم قائمة المشاركة العادية بتاعة الموبايل، وواتساب والفيسبوك
/// والإنستجرام كلهم بيظهروا فيها تلقائيًا لو متثبتين على الجهاز.
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final _repository = MarketingRepository();
  List<Offer> _offers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final offers = await _repository.getAllOffers();
    setState(() {
      _offers = offers;
      _loading = false;
    });
  }

  Future<void> _addOffer() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String? imagePath;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text('عرض تسويقي جديد'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'عنوان العرض'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'تفاصيل العرض'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  if (imagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(imagePath!), height: 140, fit: BoxFit.cover),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera_alt_outlined),
                                title: const Text('التقاط صورة'),
                                onTap: () => Navigator.pop(context, ImageSource.camera),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library_outlined),
                                title: const Text('اختيار من المعرض'),
                                onTap: () => Navigator.pop(context, ImageSource.gallery),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (source == null) return;
                      final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1200);
                      if (picked != null) dialogSetState(() => imagePath = picked.path);
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(imagePath == null ? 'إضافة صورة (اختياري)' : 'تغيير الصورة'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await _repository.addOffer(Offer(
      title: titleController.text.trim(),
      description: descController.text.trim().isEmpty ? null : descController.text.trim(),
      imagePath: imagePath,
      createdAt: DateTime.now().toIso8601String(),
    ));
    _load();
  }

  Future<void> _shareOffer(Offer offer) async {
    final text = '${offer.title}${offer.description != null ? '\n\n${offer.description}' : ''}';
    if (offer.imagePath != null && File(offer.imagePath!).existsSync()) {
      await Share.shareXFiles([XFile(offer.imagePath!)], text: text);
    } else {
      await Share.share(text);
    }
  }

  Future<void> _deleteOffer(Offer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العرض'),
        content: Text('هل تريد حذف "${offer.title}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteOffer(offer.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العروض التسويقية')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOffer,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('عرض جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offers.isEmpty
              ? const Center(child: Text('لا توجد عروض مضافة حتى الآن'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _offers.length,
                  itemBuilder: (context, index) {
                    final offer = _offers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (offer.imagePath != null && File(offer.imagePath!).existsSync())
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              child: Image.file(File(offer.imagePath!), height: 160, width: double.infinity, fit: BoxFit.cover),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(offer.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (offer.description != null) ...[
                                  const SizedBox(height: 4),
                                  Text(offer.description!),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _shareOffer(offer),
                                        icon: const Icon(Icons.share_outlined),
                                        label: const Text('مشاركة على واتساب / سوشيال ميديا'),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteOffer(offer),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
