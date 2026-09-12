import 'dart:io';
import 'package:mailer/mailer.dart' as mailer_pkg;
import 'package:mailer/smtp_server.dart';

/// إرسال إيميلات عبر SMTP - مستخدم لإرسال التقارير الدورية (يومي/
/// أسبوعي/شهري) لمدير المحل. بيانات السيرفر (Host/Port/Username/
/// Password) بتتخزن في إعدادات التطبيق وبتتبعت هنا وقت الإرسال.
///
/// ملحوظة: أي مزوّد إيميل (Gmail، Outlook، أي استضافة) ينفع طالما
/// عندك بيانات SMTP بتاعته. لو بتستخدم Gmail: لازم "App Password"
/// مش الباسورد العادي بتاع الحساب (Google بتمنع الباسورد العادي
/// من الاتصال المباشر لأسباب أمان).
class EmailService {
  Future<void> send({
    required String host,
    required int port,
    required String username,
    required String password,
    required String to,
    required String subject,
    required String body,
    File? attachment,
    bool useSsl = true,
  }) async {
    final smtpServer = SmtpServer(
      host,
      port: port,
      username: username,
      password: password,
      ssl: useSsl,
    );

    final message = mailer_pkg.Message()
      ..from = mailer_pkg.Address(username)
      ..recipients.add(to)
      ..subject = subject
      ..text = body;

    if (attachment != null) {
      message.attachments.add(mailer_pkg.FileAttachment(attachment));
    }

    await mailer_pkg.send(message, smtpServer);
  }
}
