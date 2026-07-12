/// تمثيل موحّد للقراءة فقط لعملية مالية بين طرفين (فندق/شخص/مورد)، مبني فوق
/// نظامين حقيقيين موجودين في المشروع: دفتر الأستاذ (FinancialEngine —
/// financial_accounts/financial_ledger) ونظام التسويات (Settlements —
/// settlements/settlement_transactions). هذا الكلاس لا يغيّر أياً من
/// النظامين ولا يدمجهما فعلياً؛ فقط يعرض عملياتهما بشكل قابل للعرض الموحّد
/// داخل قسم "العلاقات المالية" بمركز التحليل، مع الإبقاء على مصدر كل عملية
/// واضحاً (source) حتى لا يختفي أصل الرقم.
class RelationshipTxn {
  final String source; // 'ledger' أو 'settlement'
  final int id;
  final int hotelId;
  final String hotelName;
  final String counterpartyType; // 'hotel' | 'person' | 'supplier'
  final String counterpartyName;
  final int? counterpartyHotelId;
  final double amount;
  final bool isReceivable; // true = الطرف الآخر مدين لهذا الفندق
  final DateTime date;
  final String description;
  final String operationType;
  final String status;
  final int? reportId;
  final List<String> attachments;
  final String payerName;
  final String beneficiaryName;
  final String viaAccount; // الخزنة/البنك/... إن وُجد

  const RelationshipTxn({
    required this.source,
    required this.id,
    required this.hotelId,
    required this.hotelName,
    required this.counterpartyType,
    required this.counterpartyName,
    this.counterpartyHotelId,
    required this.amount,
    required this.isReceivable,
    required this.date,
    required this.description,
    required this.operationType,
    required this.status,
    this.reportId,
    this.attachments = const [],
    required this.payerName,
    required this.beneficiaryName,
    this.viaAccount = '',
  });
}
