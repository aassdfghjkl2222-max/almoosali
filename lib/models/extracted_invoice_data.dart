/// مصدر استخراج بيانات الفاتورة — يحدد كيف تصرَّفت شاشة المراجعة (تحذير دقة
/// أقل عند [localOcr]) ويُستخدم للتشخيص/التسجيل فقط، لا يؤثر على أي حساب.
enum InvoiceExtractionSource { zatcaQr, aiVision, localOcr }

/// بيانات فاتورة مُستخرَجة — من رمز QR (ZATCA) أو ذكاء اصطناعي سحابي أو OCR
/// محلي احتياطي، عبر نفس البنية الموحّدة (سابقاً `ZatcaInvoiceData` خاصة
/// بـQR فقط، وُسِّعت لتخدم الأنواع الثلاثة). كل حقل Nullable لأن أياً منها
/// قد يتعذّر استخراجه — عدم وجود حقل ليس خطأ، تبقى الحقول المتوفرة فقط.
class ExtractedInvoiceData {
  final String? sellerName;
  final String? vatNumber;
  final String? invoiceNumber;
  final DateTime? timestamp;
  final double? invoiceTotal;
  final double? vatTotal;
  final String? currency;
  final InvoiceExtractionSource source;

  const ExtractedInvoiceData({
    this.sellerName,
    this.vatNumber,
    this.invoiceNumber,
    this.timestamp,
    this.invoiceTotal,
    this.vatTotal,
    this.currency,
    required this.source,
  });

  /// الإجمالي قبل الضريبة = الإجمالي − الضريبة الفعليان (أدق من أي تقريب
  /// بنسبة 15% مفترضة) — null إن غاب أحدهما.
  double? get amountBeforeTax {
    if (invoiceTotal == null || vatTotal == null) return null;
    return double.parse((invoiceTotal! - vatTotal!).toStringAsFixed(2));
  }

  bool get hasAnyField =>
      sellerName != null || vatNumber != null || invoiceNumber != null || timestamp != null || invoiceTotal != null || vatTotal != null;

  /// هل تحتوي كل الحقول الجوهرية اللازمة لعرض الفاتورة مباشرة دون حاجة
  /// لاستكمالها من مصدر ثانٍ (الرقم الضريبي + الإجمالي)؟ يُستخدم في خط
  /// الأنابيب لتقرير هل نتيجة QR "كافية" أم يجب استكمالها بذكاء اصطناعي/OCR.
  bool get isComplete => vatNumber != null && invoiceTotal != null;
}

/// يدمج نتيجتين لتكوين أفضل بيانات ممكنة: حقول [primary] تُفضَّل دائماً
/// عند توفرها (عادة QR — تشفير رقمي مباشر أدق من أي قراءة بصرية)، وأي حقل
/// ناقص فيها يُستكمَل من [secondary] (ذكاء اصطناعي/OCR). المصدر النهائي
/// المعروض للمستخدم يبقى مصدر [primary] عادةً، إلا إذا ساهم [secondary]
/// بحقل ناقص وكان مصدره OCR محلياً — عندها يُعرَض تحذير "دقة أقل" (نفس
/// شاشة المراجعة) لأن جزءاً حقيقياً من الفاتورة (قد يكون المبلغ نفسه) جاء
/// من القراءة الأقل دقة.
ExtractedInvoiceData mergeExtractedInvoiceData(ExtractedInvoiceData primary, ExtractedInvoiceData? secondary) {
  if (secondary == null) return primary;

  final sellerName = primary.sellerName ?? secondary.sellerName;
  final vatNumber = primary.vatNumber ?? secondary.vatNumber;
  final invoiceNumber = primary.invoiceNumber ?? secondary.invoiceNumber;
  final timestamp = primary.timestamp ?? secondary.timestamp;
  final invoiceTotal = primary.invoiceTotal ?? secondary.invoiceTotal;
  final vatTotal = primary.vatTotal ?? secondary.vatTotal;
  final currency = primary.currency ?? secondary.currency;

  final secondaryContributed = sellerName != primary.sellerName ||
      vatNumber != primary.vatNumber ||
      invoiceNumber != primary.invoiceNumber ||
      timestamp != primary.timestamp ||
      invoiceTotal != primary.invoiceTotal ||
      vatTotal != primary.vatTotal ||
      currency != primary.currency;

  return ExtractedInvoiceData(
    sellerName: sellerName,
    vatNumber: vatNumber,
    invoiceNumber: invoiceNumber,
    timestamp: timestamp,
    invoiceTotal: invoiceTotal,
    vatTotal: vatTotal,
    currency: currency,
    source: secondaryContributed && secondary.source == InvoiceExtractionSource.localOcr
        ? InvoiceExtractionSource.localOcr
        : primary.source,
  );
}
