import '../models/app_user.dart';

/// بيحتفظ بالمستخدم اللي سجل دخوله في الذاكرة طول مدة تشغيل التطبيق
/// (مش بيتخزن بشكل دائم - كل ما التطبيق يتقفل، لازم تسجيل دخول تاني،
/// وده مقصود لأسباب أمان في بيئة نقطة بيع بيستخدمها أكتر من موظف)
class CurrentSession {
  CurrentSession._internal();
  static final CurrentSession instance = CurrentSession._internal();

  AppUser? _user;
  int? _shiftId;
  String? _shiftLoginTime;

  AppUser? get user => _user;
  int? get shiftId => _shiftId;
  String? get shiftLoginTime => _shiftLoginTime;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  void login(AppUser user, {required int shiftId, required String shiftLoginTime}) {
    _user = user;
    _shiftId = shiftId;
    _shiftLoginTime = shiftLoginTime;
  }

  void logout() {
    _user = null;
    _shiftId = null;
    _shiftLoginTime = null;
  }
}
