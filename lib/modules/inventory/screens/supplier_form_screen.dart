import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/supplier.dart';
import '../repository/supplier_repository.dart';
import '../../../core/utils/document_picker.dart';
import '../../../core/widgets/document_preview.dart';

/// أنواع مستندات المورد - نفس القائمة المستخدمة في شاشة المستندات الكاملة
/// (supplier_documents_screen.dart) عشان الاتنين يفضلوا متطابقين.
const _supplierDocTypes = {
  'contract': 'عقد توريد',
  'invoice': 'فاتورة توريد',
  'other': 'مستند آخر',
};

/// إضافة/تعديل بيانات مورد بالكامل، بما فيها إيميله وصورة كارت الشركة
/// ومستنداته (عقود/فواتير توريد). أشخاص التواصل بيتضافوا من شاشة بروفايل
/// المورد بعد ما يتحفظ.
class SupplierFormScreen extends StatefulWidget {
  final Supplier? supplier;

  const SupplierFormScreen({super.key, this.supplier});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = SupplierRepository();

  late final TextEditingController _companyController;
  late final TextEditingController _contactController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  String? _logoPath;
  bool _saving = false;

  // مستندات المورد: في وضع التعديل بنحملهم من قاعدة البيانات مباشرة،
  // وفي وضع الإضافة بنخزنهم مؤقتًا لحد ما المورد يتحفظ ويبقى له id
  List<Map<String, dynamic>> _existingDocuments = [];
  final List<Map<String, String?>> _pendingDocuments = [];
  bool _loadingDocuments = false;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _companyController = TextEditingController(text: s?.companyName ?? '');
    _contactController = TextEditingController(text: s?.contactPerson ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _notesController = TextEditingController(text: s?.notes ?? '');
    _logoPath = s?.logoPath;
    if (_isEditing) _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocuments = true);
    final docs = await _repository.getDocumentsForSupplier(widget.supplier!.id!);
    setState(() {
      _existingDocuments = docs;
      _loadingDocuments = false;
    });
  }

  Future<void> _addDocument() async {
    final pickedPath = await DocumentPicker.pick(context);
    if (pickedPath == null) return;

    String docType = 'contract';
    DateTime? expiryDate;
    final titleController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text('بيانات المستند'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: docType,
                decoration: const InputDecoration(labelText: 'نوع المستند'),
                items: _supplierDocTypes.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => dialogSetState(() => docType = v ?? 'contract'),
              ),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'عنوان (اختياري)'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(expiryDate == null
                    ? 'تاريخ انتهاء الصلاحية (اختياري)'
                    : 'ينتهي في: ${expiryDate!.toIso8601String().substring(0, 10)}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: expiryDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) dialogSetState(() => expiryDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final title = titleController.text.trim().isEmpty ? null : titleController.text.trim();
    final expiryIso = expiryDate?.toIso8601String();

    if (_isEditing) {
      await _repository.addDocument(
        supplierId: widget.supplier!.id!,
        docType: docType,
        title: title,
        filePath: pickedPath,
        expiryDate: expiryIso,
      );
      _loadDocuments();
    } else {
      setState(() {
        _pendingDocuments.add({
          'doc_type': docType,
          'title': title,
          'file_path': pickedPath,
          'expiry_date': expiryIso,
        });
      });
    }
  }

  Future<void> _deleteExistingDocument(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المستند'),
        content: const Text('هل تريد حذف هذا المستند؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteDocument(id);
    _loadDocuments();
  }

  void _removePendingDocument(int index) {
    setState(() => _pendingDocuments.removeAt(index));
  }

  Future<void> _pickLogo() async {
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
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 1000);
    if (picked != null) setState(() => _logoPath = picked.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final supplier = Supplier(
      id: widget.supplier?.id,
      companyName: _companyController.text.trim(),
      contactPerson: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      logoPath: _logoPath,
      // مهم: لازم نحافظ على الرصيد الحالي عند تعديل بيانات المورد، عشان
      // تعديل الاسم/التليفون مثلاً ميصفرش رصيده المستحق بالغلط
      balance: widget.supplier?.balance ?? 0,
    );

    if (_isEditing) {
      await _repository.updateSupplier(supplier);
      if (mounted) Navigator.pop(context, supplier);
    } else {
      final id = await _repository.addSupplier(supplier);
      // بعد ما اتحفظ المورد وبقى له id، نرحّل كل المستندات اللي اتضافت
      // مؤقتًا وهو لسه ما اتحفظش
      for (final doc in _pendingDocuments) {
        await _repository.addDocument(
          supplierId: id,
          docType: doc['doc_type']!,
          title: doc['title'],
          filePath: doc['file_path']!,
          expiryDate: doc['expiry_date'],
        );
      }
      if (mounted) {
        Navigator.pop(
          context,
          Supplier(
            id: id,
            companyName: supplier.companyName,
            contactPerson: supplier.contactPerson,
            phone: supplier.phone,
            email: supplier.email,
            address: supplier.address,
            notes: supplier.notes,
            logoPath: supplier.logoPath,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل بيانات مورد' : 'مورد جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    image: _logoPath != null
                        ? DecorationImage(image: FileImage(File(_logoPath!)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _logoPath == null
                      ? const Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.grey)
                      : null,
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _pickLogo,
                child: const Text('صورة كارت الشركة / اللوجو'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: 'اسم الشركة/المحل'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(labelText: 'اسم المندوب / المسؤول الرئيسي'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'التليفون'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'الإيميل'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: 16),
            _buildDocumentsSection(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  /// قسم مستندات المورد جوه الفورم نفسه - عقود توريد، فواتير، أو أي مستند
  /// تاني، عدد غير محدود من الصور، شغالة سواء بتضيف مورد جديد أو بتعدل
  /// واحد موجود (في حالة الإضافة بتترحّل تلقائيًا بعد الحفظ).
  Widget _buildDocumentsSection() {
    final totalCount = _existingDocuments.length + _pendingDocuments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'مستندات المورد${totalCount > 0 ? ' ($totalCount)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: _addDocument,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('إضافة'),
            ),
          ],
        ),
        Text(
          'عقد توريد، فاتورة توريد، أو أي مستند آخر - تقدر تضيف أكتر من مستند بنفس النوع، صورة أو ملف PDF.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (_loadingDocuments)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else if (totalCount == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('لسه مفيش مستندات مضافة'),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              final isExisting = index < _existingDocuments.length;
              final path = isExisting
                  ? _existingDocuments[index]['file_path'] as String
                  : _pendingDocuments[index - _existingDocuments.length]['file_path']!;
              final docTypeKey = isExisting
                  ? _existingDocuments[index]['doc_type'] as String?
                  : _pendingDocuments[index - _existingDocuments.length]['doc_type'];
              final docTypeLabel = _supplierDocTypes[docTypeKey] ?? 'مستند';

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                      child: Column(
                        children: [
                          Expanded(
                            child: DocumentPreview(path: path),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              docTypeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: InkWell(
                      onTap: () => isExisting
                          ? _deleteExistingDocument(_existingDocuments[index]['id'] as int)
                          : _removePendingDocument(index - _existingDocuments.length),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
