import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/extracted_invoice_data.dart';
import 'invoice_ai_provider.dart';

/// مزوّد Gemini (Google Generative Language API) — نموذج الرؤية اسم ثابت
/// واحد سهل التحديث لاحقاً إن غيّرت Google أسماء نماذجها.
class GeminiInvoiceAiProvider implements InvoiceAiProvider {
  @override
  String get id => 'gemini';
  @override
  String get displayName => 'Gemini (Google)';

  static const _model = 'gemini-2.0-flash';

  @override
  Future<List<ExtractedInvoiceData>> extractFromImages(List<Uint8List> images, {required String apiKey}) async {
    final parts = <Map<String, dynamic>>[
      {'text': kInvoiceExtractionPrompt},
      for (final img in images)
        {
          'inline_data': {'mime_type': 'image/png', 'data': base64Encode(img)},
        },
    ];

    final endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey';

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {'parts': parts},
              ],
              'generationConfig': {'response_mime_type': 'application/json'},
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw const InvoiceAiException('تعذّر الاتصال بخدمة Gemini');
    }

    if (response.statusCode != 200) {
      throw InvoiceAiException('فشل الاتصال بخدمة Gemini (${response.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    String text = '';
    if (candidates != null && candidates.isNotEmpty) {
      final contentParts = (candidates.first['content']?['parts'] as List?) ?? const [];
      text = contentParts.map((p) => (p as Map)['text']?.toString() ?? '').join();
    }
    return parseInvoiceExtractionJson(text, InvoiceExtractionSource.aiVision);
  }
}
