import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supa_invoice.dart';
import '../supabase_config.dart';

/// فواتير الشراء الضريبية — الإنشاء يمرّ حصراً عبر create_invoice (RPC)
/// حتى يبقى إنشاء دين المورد (عند التمويل الآجل) وسجل التدقيق ذرّيَّين مع
/// الفاتورة نفسها — راجع تعليق
/// supabase/migrations/20260730000003_phase3_rpcs.sql.
class SupaInvoiceRepository {
  SupabaseClient get _db => SupabaseConfig.client;

  Future<List<SupaInvoice>> getInvoices({required String hotelId}) async {
    final rows = await _db.from('invoices').select().eq('hotel_id', hotelId).order('invoice_date', ascending: false);
    return (rows as List).map((m) => SupaInvoice.fromMap(m as Map<String, dynamic>)).toList();
  }

  /// تحقق تكرار "غير مانع" — نفس فلسفة findDuplicateInvoice في النسخة
  /// المحلية: يُستخدَم لتحذير المستخدم فقط، لا لمنعه (قد تتكرر فاتورة
  /// بمشروعية، مثل مشتريات متطابقة من نفس المورد في تواريخ مختلفة).
  Future<SupaInvoice?> findDuplicateByNumber({
    required String hotelId,
    required String supplierId,
    required String invoiceNumber,
  }) async {
    final row = await _db
        .from('invoices')
        .select()
        .eq('hotel_id', hotelId)
        .eq('supplier_id', supplierId)
        .eq('invoice_number', invoiceNumber)
        .maybeSingle();
    return row == null ? null : SupaInvoice.fromMap(row);
  }

  Future<SupaInvoice?> findDuplicateByContent({
    required String hotelId,
    required String supplierId,
    required String invoiceDate,
    required double totalAmount,
  }) async {
    final row = await _db
        .from('invoices')
        .select()
        .eq('hotel_id', hotelId)
        .eq('supplier_id', supplierId)
        .eq('invoice_date', invoiceDate)
        .eq('total_amount', totalAmount)
        .maybeSingle();
    return row == null ? null : SupaInvoice.fromMap(row);
  }

  Future<String> createInvoice(SupaInvoice invoice) async {
    final id = await _db.rpc('create_invoice', params: {
      'p_hotel_id': invoice.hotelId,
      'p_supplier_id': invoice.supplierId,
      'p_invoice_number': invoice.invoiceNumber,
      'p_invoice_date': invoice.invoiceDate,
      'p_amount_before_tax': invoice.amountBeforeTax,
      'p_vat': invoice.vat,
      'p_total_amount': invoice.totalAmount,
      'p_category_id': invoice.categoryId,
      'p_funding_source_type': invoice.fundingSourceType,
      'p_payment_method': invoice.paymentMethod,
      'p_related_hotel_id': invoice.relatedHotelId,
    }) as String;
    return id;
  }
}
