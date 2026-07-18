import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../models/invoice.dart';
import '../../models/invoice_attachment.dart';
import '../../models/invoice_audit_log_entry.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/invoice_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/attachment_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../core/hotel_visual_identity.dart';
import 'add_invoice_page.dart';
import 'invoice_audit_log_page.dart';
import 'supplier_report_page.dart';
import 'supplier_statement_page.dart';

class InvoiceDetailsPage extends StatefulWidget {
  final Hotel hotel;
  final Invoice invoice;

  const InvoiceDetailsPage({super.key, required this.hotel, required this.invoice});

  @override
  State<InvoiceDetailsPage> createState() => _InvoiceDetailsPageState();
}

class _InvoiceDetailsPageState extends State<InvoiceDetailsPage> {
  final _repository = InvoiceRepository();
  final _supplierRepository = SupplierRepository();
  final _hotelRepository = HotelRepository();
  late Invoice _currentInvoice;

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  bool _isLoadingAttachments = true;
  List<InvoiceAttachment> _attachments = [];
  String? _relatedHotelName;

  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;
    _loadAttachments();
    _loadRelatedHotel();
  }

  Future<void> _loadAttachments() async {
    if (_currentInvoice.id == null) return;
    final attachments = await _repository.getAttachments(_currentInvoice.id!);
    if (!mounted) return;
    setState(() {
      _attachments = attachments;
      _isLoadingAttachments = false;
    });
  }

  Future<void> _loadRelatedHotel() async {
    if (_currentInvoice.relatedHotelId == null) return;
    final hotels = await _hotelRepository.getAllHotels();
    final match = hotels.where((h) => h.id == _currentInvoice.relatedHotelId);
    if (!mounted || match.isEmpty) return;
    setState(() => _relatedHotelName = match.first.arabicName);
  }

  // ---------------- المرفقات ----------------

  Future<void> _addImages() async {
    final picked = await AttachmentService.pickImages();
    if (picked.isEmpty || _currentInvoice.id == null) return;
    for (final file in picked) {
      await _repository.addAttachment(InvoiceAttachment(
        invoiceId: _currentInvoice.id!,
        hotelId: widget.hotel.id!,
        filePath: file.path,
        fileType: 'image',
        fileName: file.name,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }
    await _loadAttachments();
  }

  Future<void> _addPdf() async {
    final picked = await AttachmentService.pickPdf();
    if (picked == null || _currentInvoice.id == null) return;
    await _repository.addAttachment(InvoiceAttachment(
      invoiceId: _currentInvoice.id!,
      hotelId: widget.hotel.id!,
      filePath: picked.path,
      fileType: 'pdf',
      fileName: picked.name,
      createdAt: DateTime.now().toIso8601String(),
    ));
    await _loadAttachments();
  }

  Future<void> _deleteAttachment(InvoiceAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("حذف المرفق"),
        content: const Text("هل تريد حذف هذا المرفق نهائياً؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("حذف", style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || attachment.id == null) return;
    await _repository.deleteAttachment(attachment.id!);
    await AttachmentService.deleteFile(attachment.filePath);
    await _loadAttachments();
  }

  Future<void> _replaceAttachment(InvoiceAttachment attachment) async {
    if (attachment.id == null) return;
    await _repository.deleteAttachment(attachment.id!);
    await AttachmentService.deleteFile(attachment.filePath);
    if (attachment.isPdf) {
      await _addPdf();
    } else {
      await _addImages();
    }
  }

  // ---------------- التعديل ----------------

  void _editInvoice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInvoicePage(hotel: widget.hotel, invoice: _currentInvoice),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  // ---------------- الحذف (بمعاينة الأثر) ----------------

  Future<void> _confirmDelete() async {
    if (_currentInvoice.id == null) return;
    final hasDebt = await _supplierRepository.hasDebtForInvoice(_currentInvoice.id!);
    if (!mounted) return;

    final impactLines = <String>["إزالة الفاتورة نهائياً من السجلات."];
    if (_attachments.isNotEmpty) impactLines.add("إزالة ${_attachments.length} مرفق(ات) مرتبط(ة) بها.");
    if (hasDebt) impactLines.add("إزالة المديونية المرتبطة بها من كشف حساب المورد.");

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("تأكيد حذف الفاتورة"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("سيؤدي حذف هذه الفاتورة إلى:"),
            const SizedBox(height: AppSizes.sm),
            ...impactLines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• "),
                      Expanded(child: Text(line)),
                    ],
                  ),
                )),
            const SizedBox(height: AppSizes.sm),
            const Text("هذا الإجراء نهائي ولا يمكن التراجع عنه.", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("حذف نهائياً", style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _performDelete();
  }

  Future<void> _performDelete() async {
    final invoiceId = _currentInvoice.id!;

    // نسجّل عملية الحذف أولاً في سجل التعديلات (يبقى بعد حذف الفاتورة نفسها).
    await _repository.logAudit(InvoiceAuditLogEntry(
      invoiceId: invoiceId,
      hotelId: widget.hotel.id!,
      username: kInvoiceAuditDefaultUsername,
      operationType: 'delete',
      changedFields: "رقم الفاتورة: ${_currentInvoice.invoiceNumber} — ${_currentInvoice.companyName} — ${_currentInvoice.totalAmount} ريال",
      occurredAt: DateTime.now().toIso8601String(),
    ));

    // حذف الملفات الفعلية للمرفقات (سجلاتها في قاعدة البيانات تُحذف تلقائياً
    // مع الفاتورة عبر ON DELETE CASCADE، لكن الملفات نفسها تحتاج حذفاً يدوياً).
    for (final attachment in _attachments) {
      await AttachmentService.deleteFile(attachment.filePath);
    }

    await _repository.deleteInvoice(invoiceId);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = _identityColor;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'audit_log' && _currentInvoice.id != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceAuditLogPage(
                      hotel: widget.hotel,
                      invoiceId: _currentInvoice.id!,
                      invoiceLabel: "فاتورة رقم ${_currentInvoice.invoiceNumber} — ${_currentInvoice.companyName}",
                    ),
                  ),
                );
              } else if (value == 'supplier_statement') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SupplierStatementPage(hotel: widget.hotel, companyName: _currentInvoice.companyName)),
                );
              } else if (value == 'supplier_report') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SupplierReportPage(hotel: widget.hotel, companyName: _currentInvoice.companyName)),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'audit_log', child: Row(children: [Icon(Icons.history, size: 18), SizedBox(width: 8), Text("سجل التعديلات")])),
              PopupMenuItem(value: 'supplier_statement', child: Row(children: [Icon(Icons.receipt_long_outlined, size: 18), SizedBox(width: 8), Text("كشف حساب المورد")])),
              PopupMenuItem(value: 'supplier_report', child: Row(children: [Icon(Icons.summarize_outlined, size: 18), SizedBox(width: 8), Text("تقرير هذا المورد")])),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          AppCard(
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
                _buildDetailItem("تصنيف المصروف", _currentInvoice.expenseCategory ?? "غير مصنَّف"),
                _buildDetailItem("مصدر التمويل", _currentInvoice.amountSource),
                if (_currentInvoice.paymentMethod != null) _buildDetailItem("طريقة الدفع", _currentInvoice.paymentMethod!),
                if (_relatedHotelName != null) _buildDetailItem("الفندق المرتبط", _relatedHotelName!),
                const Divider(height: AppSizes.lg),
                _buildDetailItem("المنشأة", _currentInvoice.facilityName),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          _buildAttachmentsSection(),
        ],
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
            style: AppTextStyles.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: AppTextStyles.bodyBold.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: color ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("المرفقات", style: AppTextStyles.bodyBold),
              const Spacer(),
              IconButton(
                onPressed: _addImages,
                icon: Icon(Icons.add_photo_alternate_outlined, color: _identityColor),
                tooltip: "إرفاق صورة",
              ),
              IconButton(
                onPressed: _addPdf,
                icon: Icon(Icons.picture_as_pdf_outlined, color: _identityColor),
                tooltip: "إرفاق PDF",
              ),
            ],
          ),
          if (_isLoadingAttachments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
              child: Text("لا توجد مرفقات بعد", style: AppTextStyles.caption),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _attachments.map(_buildAttachmentTile).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(InvoiceAttachment attachment) {
    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => OpenFilex.open(attachment.filePath),
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: attachment.isPdf
                ? const Center(child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 36))
                : Image.file(File(attachment.filePath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
          ),
        ),
        Positioned(
          top: 2,
          left: 2,
          child: GestureDetector(
            onTap: () => _showAttachmentMenu(attachment),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.more_vert, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _showAttachmentMenu(InvoiceAttachment attachment) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text("فتح"),
              onTap: () {
                Navigator.pop(sheetContext);
                OpenFilex.open(attachment.filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text("استبدال"),
              onTap: () {
                Navigator.pop(sheetContext);
                _replaceAttachment(attachment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text("حذف", style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteAttachment(attachment);
              },
            ),
          ],
        ),
      ),
    );
  }
}
