import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/app_preferences.dart';
import '../../models/extracted_invoice_data.dart';
import '../security_service.dart';
import 'claude_invoice_ai_provider.dart';
import 'gemini_invoice_ai_provider.dart';
import 'invoice_ai_provider.dart';
import 'openai_invoice_ai_provider.dart';

/// منسِّق مزوّدي الذكاء الاصطناعي — يقرأ المزوّد النشط ومفتاحه من الإعدادات،
/// يفحص الاتصال، ويستدعي التطبيق المناسب. إضافة مزوّد رابع = تسجيله في
/// [_providers] فقط، بلا أي تعديل آخر في التطبيق (خط الأنابيب/الإعدادات/
/// الشاشات لا تعرف أسماء المزوّدين، تتعامل معهم عبر هذه القائمة فقط).
class InvoiceAiService {
  InvoiceAiService._();

  static final Map<String, InvoiceAiProvider> _providers = {
    'claude': ClaudeInvoiceAiProvider(),
    'openai': OpenAiInvoiceAiProvider(),
    'gemini': GeminiInvoiceAiProvider(),
  };

  static List<InvoiceAiProvider> get availableProviders => _providers.values.toList(growable: false);

  static InvoiceAiProvider? providerById(String id) => _providers[id];

  static Future<bool> _hasInternetConnection() async {
    final result = await Connectivity().checkConnectivity();
    return !result.every((r) => r == ConnectivityResult.none);
  }

  /// يستخرج بيانات الفاتورة من صور جاهزة (بايتات PNG) عبر المزوّد النشط
  /// المُختار من الإعدادات. يرمي [InvoiceAiException] إن كانت الميزة
  /// معطَّلة، أو لا يوجد مزوّد/مفتاح صالح، أو لا يوجد اتصال إنترنت، أو فشل
  /// الاتصال الفعلي — خط الأنابيب المستدعي يلتقط هذا للسقوط نحو OCR المحلي.
  static Future<List<ExtractedInvoiceData>> extractFromImages(List<Uint8List> images) async {
    final enabled = await AppPreferences.getBool(AppPreferences.keyAiOcrEnabled);
    if (!enabled) {
      throw const InvoiceAiException('القراءة الذكية غير مفعَّلة من الإعدادات');
    }

    final providerId = await AppPreferences.getString(AppPreferences.keyAiOcrProvider, defaultValue: 'claude');
    final provider = providerById(providerId);
    if (provider == null) {
      throw const InvoiceAiException('لم يتم اختيار مزوّد ذكاء اصطناعي صالح');
    }

    final apiKey = await SecurityService.instance.getAiApiKey(providerId);
    if (apiKey == null || apiKey.isEmpty) {
      throw InvoiceAiException('لم يتم إدخال مفتاح ${provider.displayName} من الإعدادات');
    }

    if (!await _hasInternetConnection()) {
      throw const InvoiceAiException('لا يوجد اتصال بالإنترنت');
    }

    return await provider.extractFromImages(images, apiKey: apiKey);
  }
}
