import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/extracted_invoice_data.dart';
import 'invoice_ai_provider.dart';

/// مزوّد OpenAI (Chat Completions مع دخل صوري) — نموذج الرؤية اسم ثابت
/// واحد سهل التحديث لاحقاً إن غيّرت OpenAI أسماء نماذجها.
class OpenAiInvoiceAiProvider implements InvoiceAiProvider {
  @override
  String get id => 'openai';
  @override
  String get displayName => 'OpenAI (GPT-4o)';

  static const _model = 'gpt-4o';
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  @override
  Future<List<ExtractedInvoiceData>> extractFromImages(List<Uint8List> images, {required String apiKey}) async {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': kInvoiceExtractionPrompt},
      for (final img in images)
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/png;base64,${base64Encode(img)}'},
        },
    ];

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'user', 'content': content},
              ],
              'response_format': {'type': 'json_object'},
              'max_tokens': 2048,
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw const InvoiceAiException('تعذّر الاتصال بخدمة OpenAI');
    }

    if (response.statusCode != 200) {
      throw InvoiceAiException('فشل الاتصال بخدمة OpenAI (${response.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    final text = (choices != null && choices.isNotEmpty) ? (choices.first['message']?['content']?.toString() ?? '') : '';
    return parseInvoiceExtractionJson(text, InvoiceExtractionSource.aiVision);
  }
}
