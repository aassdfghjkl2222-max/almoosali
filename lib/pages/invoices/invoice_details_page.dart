import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/invoice.dart';
import '../../repositories/invoice_repository.dart';
import '../../widgets/common/app_card.dart';
import 'add_invoice_page.dart';

import '../../models/hotel.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../core/hotel_visual_identity.dart';

class InvoiceDetailsPage extends StatefulWidget {
  final Hotel hotel;
  final Invoice invoice;

  const InvoiceDetailsPage({super.key, required this.hotel, required this.invoice});

  @override
  State<InvoiceDetailsPage> createState() => _InvoiceDetailsPageState();
}

class _InvoiceDetailsPageState extends State<InvoiceDetailsPage> {
  final _repository = InvoiceRepository();
  late Invoice _currentInvoice;

  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف", textAlign: TextAlign.right),
        content: const Text("هل أنت متأكد من حذف هذه الفاتورة؟", textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () async {
              if (_currentInvoice.id != null) {
                await _repository.deleteInvoice(_currentInvoice.id!);
                if (!mounted) return;
                // نستخدم Navigator.of(context) لإغلاق الحوار ثم Navigator.of(context) مرة أخرى لإغلاق الصفحة
                // لضمان عدم وجود تحذيرات، سنستخدم Navigator من السياق الرئيسي
                final navigator = Navigator.of(this.context);
                navigator.pop(); // Close dialog
                navigator.pop(true); // Return to list
              }
            },
            child: const Text("حذف", style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _editInvoice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInvoicePage(hotel: widget.hotel, invoice: _currentInvoice),
      ),
    );

    if (result == true && mounted) {
      // بعد التعديل، نعود مباشرة إلى القائمة كما هو مطلوب
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "تفاصيل الفاتورة", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _editInvoice,
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: "تعديل",
          ),
          IconButton(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: "حذف",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem("رقم الفاتورة", _currentInvoice.invoiceNumber),
              _buildDetailItem("التاريخ", _currentInvoice.date),
              _buildDetailItem("اسم الشركة", _currentInvoice.companyName),
              _buildDetailItem("الرقم الضريبي", _currentInvoice.taxNumber),
              const Divider(height: AppSizes.lg),
              _buildDetailItem("المبلغ قبل الضريبة", "${NumberFormat("#,##0.00").format(_currentInvoice.amountBeforeTax)} ريال"),
              _buildDetailItem("ضريبة القيمة المضافة", "${NumberFormat("#,##0.00").format(_currentInvoice.vat)} ريال"),
              _buildDetailItem("المبلغ الإجمالي", "${NumberFormat("#,##0.00").format(_currentInvoice.totalAmount)} ريال", isBold: true, color: Theme.of(context).colorScheme.primary),
              const Divider(height: AppSizes.lg),
              _buildDetailItem("المنشأة", _currentInvoice.facilityName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: AppTextStyles.bodyBold.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
