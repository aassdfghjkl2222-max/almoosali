import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/extracted_invoice_data.dart';
import 'invoice_ai_provider.dart';

/// مزوّد Claude (Anthropic Messages API) — نموذج الرؤية اسم ثابت واحد سهل
/// التحديث لاحقاً إن غيّرت Anthropic أسماء نماذجها.
class ClaudeInvoiceAiProvider implements InvoiceAiProvider {
  @override
  String get id => 'claude';
  @override
  String get displayName => 'Claude (Anthropic)';

  static const _model = 'claude-sonnet-4-5-20250929';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  @override
  Future<List<ExtractedInvoiceData>> extractFromImages(List<Uint8List> images, {required String apiKey}) async {
    final content = <Map<String, dynamic>>[
      for (final img in images)
        {
          'type': 'image',
          'source': {'type': 'base64', 'media_type': 'image/png', 'data': base64Encode(img)},
        },
      {'type': 'text', 'text': kInvoiceExtractionPrompt},
    ];

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 2048,
              'messages': [
                {'role': 'user', 'content': content},
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw const InvoiceAiException('تعذّر الاتصال بخدمة Claude');
    }

    if (response.statusCode != 200) {
      throw InvoiceAiException('فشل الاتصال بخدمة Claude (${response.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final blocks = (decoded['content'] as List?) ?? const [];
    final text = blocks.map((b) => (b as Map)['text']?.toString() ?? '').join();
    return parseInvoiceExtractionJson(text, InvoiceExtractionSource.aiVision);
  }
}
