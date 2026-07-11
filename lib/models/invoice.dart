class Invoice {
  final int? id;
  final int hotelId;
  final String invoiceNumber;
  final String date;
  final String companyName;
  final String taxNumber;
  final double amountBeforeTax;
  final double vat;
  final double totalAmount;
  final String facilityName;
  final String amountSource;

  const Invoice({
    this.id,
    required this.hotelId,
    required this.invoiceNumber,
    required this.date,
    required this.companyName,
    required this.taxNumber,
    required this.amountBeforeTax,
    required this.vat,
    required this.totalAmount,
    required this.facilityName,
    this.amountSource = 'خارج النظام',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hotel_id': hotelId,
      'invoice_number': invoiceNumber,
      'date': date,
      'company_name': companyName,
      'tax_number': taxNumber,
      'amount_before_tax': amountBeforeTax,
      'vat': vat,
      'total_amount': totalAmount,
      'facility_name': facilityName,
      'amount_source': amountSource,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      hotelId: map['hotel_id'] ?? 0,
      invoiceNumber: map['invoice_number'] as String,
      date: map['date'] as String,
      companyName: map['company_name'] as String,
      taxNumber: map['tax_number'] as String,
      amountBeforeTax: (map['amount_before_tax'] as num).toDouble(),
      vat: (map['vat'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      facilityName: map['facility_name'] as String,
      amountSource: map['amount_source'] ?? 'خارج النظام',
    );
  }
}
