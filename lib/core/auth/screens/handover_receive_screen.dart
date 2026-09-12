import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/shift.dart';
import '../repository/shift_repository.dart';
import '../session/current_session.dart';
import '../../../app.dart';

/// شاشة إجبارية بتظهر لما مستخدم يسجل دخول ولقينا وردية سابقة لمستخدم
/// مختلف لسه مفتوحة (يعني اللي قبله عمل "خروج من التطبيق" بس من غير
/// "إغلاق وردية"). المستخدم الجديد لازم يأكد استلام العهدة (بمبلغ فعلي)
/// قبل ما يقدر يدخل الشاشة الرئيسية - مفيش أي طريقة تانية تعدّي الشاشة دي.
class HandoverReceiveScreen extends StatefulWidget {
  final AppUser newUser;
  final Shift openShift;
  final String previousUserName;
  /// true لو الشاشة دي ظهرت بسبب دورة الإقفال الإجباري (كل 24 ساعة مثلاً)
  /// مش بسبب دخول مستخدم مختلف - بيغيّر النص بس، نفس المنطق بالظبط
  final bool isMandatoryCycle;

  const HandoverReceiveScreen({
    super.key,
    required this.newUser,
    required this.openShift,
    required this.previousUserName,
    this.isMandatoryCycle = false,
  });

  @override
  State<HandoverReceiveScreen> createState() => _HandoverReceiveScreenState();
}

class _HandoverReceiveScreenState extends State<HandoverReceiveScreen> {
  final _repository = ShiftRepository();
  final _amountController = TextEditingController();
  Map<String, dynamic>? _summary;
  bool _loading = true;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await _repository.getShiftSummary(
      widget.openShift.userId,
      widget.openShift.loginTime,
      null,
    );
    setState(() {
      _summary = summary;
      _amountController.text = (summary['cash_total'] as double).toStringAsFixed(2);
      _loading = false;
    });
  }

  Future<void> _confirm() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب المبلغ الفعلي اللي استلمته بشكل صحيح')),
      );
      return;
    }

    setState(() => _confirming = true);
    final newShiftId = await _repository.handoverAndStartNewShift(
      openShift: widget.openShift,
      newUserId: widget.newUser.id!,
      receivedAmount: amount,
    );

    CurrentSession.instance.login(
      widget.newUser,
      shiftId: newShiftId,
      shiftLoginTime: DateTime.now().toIso8601String(),
    );
    await _repository.logAppEvent(event: 'open', shiftId: newShiftId, userId: widget.newUser.id);

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeDashboard()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.isMandatoryCycle ? 'إقفال إجباري - تسليم الحسابات' : 'استلام العهدة'),
      ),
      body: WillPopScope(
        onWillPop: () async => false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isMandatoryCycle
                                ? 'وصلت مدة الإقفال الإجباري - لازم تقفل الوردية وتسلّم الحسابات دلوقتي.'
                                : 'الوردية السابقة لـ ${widget.previousUserName} لسه مفتوحة ومتسلّمتش.',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isMandatoryCycle
                                ? 'أكّد المبلغ الفعلي الموجود دلوقتي - أي حد ممكن يستلم (نفسك، زميلك، أو المدير)، المهم الحسابات تتسلّم.'
                                : 'لازم تأكد استلام العهدة والحسابات قبل ما تقدر تشتغل.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('عدد الفواتير: ${_summary!['invoice_count']}'),
                          const SizedBox(height: 6),
                          Text(
                            'إجمالي الكاش المتوقع: ${(_summary!['cash_total'] as double).toStringAsFixed(2)} ج',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('إجمالي الفيزا/البطاقة: ${(_summary!['card_total'] as double).toStringAsFixed(2)} ج'),
                          const Divider(),
                          Text(
                            'الإجمالي الكلي: ${(_summary!['total'] as double).toStringAsFixed(2)} ج',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الفعلي اللي استلمته في الدرج/الخزنة',
                      suffixText: 'ج',
                      helperText: 'ممكن يفرق عن الرقم المتوقع فوق - أي فرق هيتسجل مع العهدة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _confirming ? null : _confirm,
                      child: Text(
                        _confirming
                            ? 'جاري التأكيد...'
                            : (widget.isMandatoryCycle ? 'تأكيد التسليم والمتابعة' : 'تأكيد الاستلام والدخول'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
