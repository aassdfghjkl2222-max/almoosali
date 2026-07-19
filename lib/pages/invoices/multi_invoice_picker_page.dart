import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/extracted_invoice_data.dart';
import '../../models/hotel.dart';
import '../../widgets/common/app_card.dart';

/// تظهر فقط عندما تكتشف القراءة الذكية أكثر من فاتورة واحدة في نفس
/// الصورة/ملف PDF — قائمة مختصرة (مورد + مبلغ) للاختيار قبل شاشة المراجعة
/// السريعة، بدل تقطيع الصورة فعلياً (غير واقعي؛ الاعتماد على مصفوفة رد
/// الذكاء الاصطناعي نفسها).
class MultiInvoicePickerPage extends StatelessWidget {
  final Hotel hotel;
  final List<ExtractedInvoiceData> invoices;
  const MultiInvoicePickerPage({super.key, required this.hotel, required this.invoices});

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    final fmt = NumberFormat("#,##0.##");
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("عدة فواتير مكتشَفة", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: AppSizes.md),
            child: Text("عثرنا على أكثر من فاتورة — اختر الفاتورة التي تريد مراجعتها أولاً", style: AppTextStyles.caption),
          ),
          for (final invoice in invoices)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: AppCard(
                onTap: () => Navigator.pop(context, invoice),
                child: Row(
                  children: [
                    Icon(Icons.receipt_outlined, color: identityColor),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        invoice.sellerName ?? "مورد غير معروف",
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      invoice.invoiceTotal != null ? "${fmt.format(invoice.invoiceTotal)} ريال" : "—",
                      style: AppTextStyles.bodyBold.copyWith(color: identityColor, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
