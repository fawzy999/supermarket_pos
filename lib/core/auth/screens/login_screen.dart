import 'package:flutter/material.dart';
import '../repository/auth_repository.dart';
import '../repository/shift_repository.dart';
import '../models/app_user.dart';
import '../session/current_session.dart';
import '../services/biometric_service.dart';
import '../repository/closing_cycle_repository.dart';
import 'handover_receive_screen.dart';
import '../../../app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _repository = AuthRepository();
  final _biometricService = BiometricService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _biometricAvailable = false;
  List<AppUser> _biometricUsers = [];

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final deviceSupported = await _biometricService.isDeviceSupported();
    if (!deviceSupported) return;
    final users = await _repository.getBiometricEnabledUsers();
    if (mounted) {
      setState(() {
        _biometricAvailable = users.isNotEmpty;
        _biometricUsers = users;
      });
    }
  }

  /// بعد التحقق من الهوية (باسورد أو بصمة) بأي طريقة - بيشيك هل فيه وردية
  /// سابقة لمستخدم مختلف لسه مفتوحة، وبيوجّه المستخدم حسب الحالة
  Future<void> _proceedAfterAuthentication(AppUser user) async {
    final shiftRepository = ShiftRepository();
    final openShift = await shiftRepository.getOpenShift();

    if (openShift == null) {
      // مفيش أي وردية مفتوحة - وردية جديدة عادي
      final now = DateTime.now().toIso8601String();
      final shiftId = await shiftRepository.startShift(user.id!);
      CurrentSession.instance.login(user, shiftId: shiftId, shiftLoginTime: now);
      await shiftRepository.logAppEvent(event: 'open', shiftId: shiftId, userId: user.id);
      _goHome();
      return;
    }

    // لو دورة الإقفال الإجباري (كل 24 ساعة مثلاً) وصلت لآخرها، لازم تسليم/استلام
    // حسابات الوردية دلوقتي حتى لو نفس المستخدم اللي هيكمّل - عشان الحسابات
    // تتقفل فعليًا كل دورة، مهما كان مين هيستلم (نفسه، زميله، أو الأدمن)
    final overdue = await ClosingCycleRepository().isOverdue();

    if (openShift.userId == user.id && !overdue) {
      // نفس المستخدم، والدورة لسه في وقتها - يكمّل نفس الوردية من غير أي دايالوج
      CurrentSession.instance.login(user, shiftId: openShift.id!, shiftLoginTime: openShift.loginTime);
      await shiftRepository.logAppEvent(event: 'open', shiftId: openShift.id, userId: user.id);
      _goHome();
      return;
    }

    // مستخدم مختلف، أو نفس المستخدم لكن الدورة الإجبارية وصلت - لازم تأكيد
    // تسليم/استلام الحسابات الأول (شاشة إجبارية) - المستلم ممكن يكون أي حد
    final previousUser = await _repository.getUserById(openShift.userId);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HandoverReceiveScreen(
          newUser: user,
          openShift: openShift,
          previousUserName: previousUser?.name ?? 'مستخدم سابق',
          isMandatoryCycle: overdue && openShift.userId == user.id,
        ),
      ),
    );
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeDashboard()));
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = await _repository.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'اسم المستخدم أو كلمة السر غلط';
      });
      return;
    }

    await _proceedAfterAuthentication(user);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loginWithBiometrics() async {
    setState(() => _error = null);
    final success = await _biometricService.authenticate();
    if (!success) return;

    AppUser targetUser;
    if (_biometricUsers.length == 1) {
      targetUser = _biometricUsers.first;
    } else {
      final selected = await showDialog<AppUser>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('مين صاحب البصمة دي؟'),
          children: _biometricUsers
              .map((u) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, u),
                    child: Text(u.name),
                  ))
              .toList(),
        ),
      );
      if (selected == null) return;
      targetUser = selected;
    }

    setState(() => _loading = true);
    await _proceedAfterAuthentication(targetUser);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/branding/codex_logo.png',
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              const Text('سوبر ماركت Codex', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 16),
              const Text('تسجيل الدخول', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'كلمة السر'),
                obscureText: true,
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  child: Text(_loading ? 'جاري الدخول...' : 'دخول'),
                ),
              ),
              if (_biometricAvailable) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _loginWithBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('دخول بالبصمة'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
