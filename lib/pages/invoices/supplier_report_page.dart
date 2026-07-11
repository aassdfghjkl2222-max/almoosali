import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/invoice.dart';
import '../../models/supplier.dart';
import '../../repositories/invoice_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../services/excel_service.dart';
import '../../models/hotel.dart';
import '../../widgets/common/hotel_identity_title.dart';
import 'invoice_details_page.dart';

class SupplierReportPage extends StatefulWidget {
  final Hotel hotel;
  final String companyName;
  final DateTime? startDate;
  final DateTime? endDate;

  const SupplierReportPage({
    super.key, 
    required this.hotel,
    required this.companyName,
    this.startDate,
    this.endDate,
  });

  @override
  State<SupplierReportPage> createState() => _SupplierReportPageState();
}

class _SupplierReportPageState extends State<SupplierReportPage> {
  final _invoiceRepository = InvoiceRepository();
  final _supplierRepository = SupplierRepository();

  Supplier? _supplier;
  List<Invoice> _invoices = [];
  bool _isLoading = true;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _supplier = await _supplierRepository.getSupplierByOfficialName(widget.hotel.id!, widget.companyName);
    
    String? startStr;
    String? endStr;
    
    if (_startDate != null) {
      startStr = "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}";
    }
    if (_endDate != null) {
      endStr = "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}";
    }

    _invoices = await _invoiceRepository.getInvoicesBySupplier(
      hotelId: widget.hotel.id!,
      companyName: widget.companyName,
      startDate: startStr,
      endDate: endStr,
    );

    setState(() => _isLoading = false);
  }

  Future<void> _filterInvoices() async {
    setState(() => _isLoading = true);
    
    String? startStr;
    String? endStr;
    
    if (_startDate != null) {
      startStr = "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}";
    }
    if (_endDate != null) {
      endStr = "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}";
    }

    _invoices = await _invoiceRepository.getInvoicesBySupplier(
      hotelId: widget.hotel.id!,
      companyName: widget.companyName,
      startDate: startStr,
      endDate: endStr,
    );

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "تقرير المورد", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () async {
              await ExcelService.exportSupplierInvoices(
                companyName: widget.companyName,
                invoices: _invoices,
                supplier: _supplier,
                fromDate: _startDate,
                toDate: _endDate,
              );
            },
            tooltip: "Excel",
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              children: [
                _buildSummaryCard(identityColor),
                const SizedBox(height: AppSizes.md),
                _buildFilterSection(identityColor),
                const SizedBox(height: AppSizes.md),
                _buildInvoicesList(identityColor),
              ],
            ),
          ),
    );
  }

  Widget _buildSummaryCard(Color identityColor) {
    double totalBeforeTax = 0;
    double totalVat = 0;
    double totalAmount = 0;
    
    for (var inv in _invoices) {
      totalBeforeTax += inv.amountBeforeTax;
      totalVat += inv.vat;
      totalAmount += inv.totalAmount;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.companyName,
            style: AppTextStyles.title.copyWith(color: identityColor),
          ),
          if (_supplier != null)
            Text(
              "الرقم الضريبي: ${_supplier!.taxNumber}",
              style: AppTextStyles.caption,
            ),
          const Divider(height: AppSizes.lg),
          _buildSummaryItem("عدد الفواتير", "${_invoices.length}"),
          _buildSummaryItem("إجمالي قبل الضريبة", "${NumberFormat("#,##0.00").format(totalBeforeTax)} ريال"),
          _buildSummaryItem("إجمالي الضريبة", "${NumberFormat("#,##0.00").format(totalVat)} ريال"),
          _buildSummaryItem("إجمالي بعد الضريبة", "${NumberFormat("#,##0.00").format(totalAmount)} ريال", isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body),
          Text(
            value, 
            style: isBold ? AppTextStyles.bodyBold : AppTextStyles.body,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(Color identityColor) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  label: "من تاريخ",
                  value: _startDate,
                  onSelect: (date) => setState(() => _startDate = date),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: _buildDatePicker(
                  label: "إلى تاريخ",
                  value: _endDate,
                  onSelect: (date) => setState(() => _endDate = date),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _filterInvoices,
              style: ElevatedButton.styleFrom(
                backgroundColor: identityColor,
                foregroundColor: Colors.white,
              ),
              child: const Text("عرض التقرير"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required Function(DateTime) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: AppSizes.xs),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (date != null) onSelect(date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: AppSizes.sm),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value == null ? "اختر التاريخ" : "${value.year}-${value.month}-${value.day}",
                  style: AppTextStyles.body,
                ),
                Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesList(Color identityColor) {
    if (_invoices.isEmpty) return const Center(child: Text("لا توجد فواتير"));

    return Column(
      children: _invoices.map((inv) => Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.md),
        child: _buildInvoiceItem(inv, identityColor),
      )).toList(),
    );
  }

  Widget _buildInvoiceItem(Invoice invoice, Color identityColor) {
    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InvoiceDetailsPage(hotel: widget.hotel, invoice: invoice)),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("رقم: ${invoice.invoiceNumber}", style: AppTextStyles.bodyBold),
              Text(invoice.date, style: AppTextStyles.caption),
            ],
          ),
          Text(
            "${NumberFormat("#,##0.00").format(invoice.totalAmount)} ريال",
            style: AppTextStyles.bodyBold.copyWith(color: Theme.of(context).colorScheme.secondary),
          ),
        ],
      ),
    );
  }
}
