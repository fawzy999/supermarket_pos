import 'dart:convert';
import 'package:http/http.dart' as http;

/// تحليل ذكي لأرقام المحل عن طريق استدعاء Claude API مباشرة من
/// التطبيق - محتاج مفتاح API يدخله الأدمن بنفسه من الإعدادات
/// (زي أي "Bring your own key")، والتطبيق مش بيخزن أو يبعت المفتاح
/// لأي حد غير Anthropic مباشرة.
class AiService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _defaultModel = 'claude-sonnet-4-5';

  /// بيبعت وصف نصي لأرقام المحل (مبيعات/أرباح/مصروفات...) ويرجّع
  /// تحليل نصي بالعربي. بيرمي Exception فيها رسالة واضحة لو حصل
  /// خطأ (مفتاح غلط، مفيش إنترنت، إلخ) عشان تتعرض للمستخدم مباشرة.
  Future<String> analyzeSalesData({
    required String apiKey,
    required String dataSummary,
    String? model,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('لازم تدخل مفتاح API الأول من إعدادات الذكاء الاصطناعي');
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey.trim(),
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': (model == null || model.trim().isEmpty) ? _defaultModel : model.trim(),
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': 'أنت محلل مبيعات لسوبر ماركت. حلّل الأرقام دي وقدّم ملخص قصير وواضح '
                'بالعربية (نقاط عملية: إيه اللي كويس، إيه اللي محتاج انتباه، واقتراح عملي '
                'واحد أو اتنين). خليك مختصر ومباشر.\n\n$dataSummary',
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      String message = 'فشل الاتصال بخدمة الذكاء الاصطناعي (كود ${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = decoded['error']?['message'];
        if (errorMessage != null) message = errorMessage.toString();
      } catch (_) {
        // تجاهل - هنستخدم الرسالة الافتراضية فوق
      }
      throw Exception(message);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['content'] as List<dynamic>?;
    if (content == null || content.isEmpty) {
      throw Exception('الرد من الخدمة جه فاضي، جرّب تاني');
    }
    final text = content.first['text'] as String?;
    return text ?? 'مفيش رد نصي واضح، جرّب تاني';
  }
}
