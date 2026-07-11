import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../models/invoice.dart';
import '../../repositories/invoice_repository.dart';
import '../../services/excel_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/hotel_identity_title.dart';
import 'add_invoice_page.dart';
import 'invoice_details_page.dart';
import 'supplier_report_page.dart';

class InvoicesPage extends StatefulWidget {
  final Hotel hotel;
  const InvoicesPage({super.key, required this.hotel});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _repository = InvoiceRepository();
  final _searchController = TextEditingController();
  late Future<List<Invoice>> _invoicesFuture;
  
  DateTime? _startDate;
  DateTime? _endDate;

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  void _loadInvoices() {
    setState(() {
      if (_startDate == null && _endDate == null) {
        _invoicesFuture = _repository.getAllInvoices(widget.hotel.id!);
      } else {
        String? startStr = _startDate != null 
            ? "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}" 
            : null;
        String? endStr = _endDate != null 
            ? "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}" 
            : null;
            
        _invoicesFuture = _repository.getFilteredInvoices(
          hotelId: widget.hotel.id!,
          startDate: startStr,
          endDate: endStr,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = _identityColor;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "الفواتير الإلكترونية", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () async {
              final invoices = await _invoicesFuture;
              await ExcelService.exportGeneralInvoicesReport(
                hotelName: widget.hotel.arabicName,
                invoices: invoices,
                fromDate: _startDate,
                toDate: _endDate,
              );
            },
            tooltip: "تقرير Excel",
          ),
        ],
      ),
      drawer: AppDrawer(hotel: widget.hotel),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: FutureBuilder<List<Invoice>>(
              future: _invoicesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final invoices = snapshot.data ?? [];

                if (invoices.isEmpty) {
                  return const Center(
                    child: Text("لا توجد فواتير مضافة حالياً"),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = invoices[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.md),
                      child: _buildInvoiceCard(invoice),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddInvoicePage(hotel: widget.hotel)),
          );
          if (result == true) {
            _loadInvoices();
          }
        },
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final identityColor = _identityColor;
    return AppCard(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailsPage(invoice: invoice, hotel: widget.hotel),
          ),
        );
        if (result == true) {
          _loadInvoices();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "رقم الفاتورة: ${invoice.invoiceNumber}",
                style: AppTextStyles.bodyBold.copyWith(color: identityColor),
              ),
              Text(
                invoice.date,
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const Divider(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.companyName,
                  style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Text("📊", style: TextStyle(fontSize: 20)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierReportPage(
                        hotel: widget.hotel,
                        companyName: invoice.companyName,
                        startDate: _startDate,
                        endDate: _endDate,
                      ),
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: "تقرير المورد",
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${NumberFormat("#,##0.00").format(invoice.totalAmount)} ريال",
                style: AppTextStyles.bodyBold.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: identityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  invoice.facilityName,
                  style: AppTextStyles.caption.copyWith(color: identityColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    final identityColor = _identityColor;
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: identityColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.lg),
          bottomRight: Radius.circular(AppRadius.lg),
        ),
      ),
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
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _loadInvoices,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      "عرض التقرير",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _showSummaryDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: identityColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined, size: 18),
                        SizedBox(width: 4),
                        Text(
                          "الإجمالي",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog() async {
    final invoices = await _invoicesFuture;
    
    double totalBeforeTax = 0;
    double totalVat = 0;
    double totalAmount = 0;
    
    for (var inv in invoices) {
      totalBeforeTax += inv.amountBeforeTax;
      totalVat += inv.vat;
      totalAmount += inv.totalAmount;
    }

    double avgValue = invoices.isEmpty ? 0 : totalAmount / invoices.length;
    String firstInvoice = invoices.isEmpty ? "-" : invoices.last.date;
    String lastInvoice = invoices.isEmpty ? "-" : invoices.first.date;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Column(
          children: [
            Text(
              "ملخص التقرير",
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              widget.hotel.arabicName,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow("عدد الفواتير", "${invoices.length}"),
            const Divider(),
            _buildSummaryRow("إجمالي قبل الضريبة", "${NumberFormat("#,##0.00").format(totalBeforeTax)} ريال"),
            _buildSummaryRow("إجمالي الضريبة", "${NumberFormat("#,##0.00").format(totalVat)} ريال"),
            _buildSummaryRow("إجمالي بعد الضريبة", "${NumberFormat("#,##0.00").format(totalAmount)} ريال", isBold: true),
            const Divider(),
            _buildSummaryRow("متوسط قيمة الفاتورة", "${NumberFormat("#,##0.00").format(avgValue)} ريال"),
            _buildSummaryRow("أول فاتورة", firstInvoice),
            _buildSummaryRow("آخر فاتورة", lastInvoice),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("إغلاق", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Theme.of(context).colorScheme.secondary : AppColors.textPrimary,
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
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: _identityColor,
                      onPrimary: Colors.white,
                      onSurface: _identityColor,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) onSelect(date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value == null ? "اختر التاريخ" : "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}",
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
