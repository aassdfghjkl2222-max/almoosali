import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../models/supplier.dart';
import '../../repositories/invoice_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';
import 'invoice_details_page.dart';
import 'supplier_documents_tab.dart';

/// بطاقة المورد — تبويبان: "كشف الحساب" (إجماليات الفواتير والمسدد
/// والمتبقي، وقائمة كل العمليات مرتبة زمنياً) و"مستندات المورد" (محرك
/// المستندات الموحّد). لا توجد شاشة سداد هنا — عرض فقط؛ السداد سيُضاف
/// مستقبلاً من قسم الموردين أو المركز المالي وسيُحدِّث هذا الكشف تلقائياً
/// فور توفره لأنه يقرأ مباشرة من نفس الجداول.
class SupplierStatementPage extends StatefulWidget {
  final Hotel hotel;
  final String companyName;
  const SupplierStatementPage({super.key, required this.hotel, required this.companyName});

  @override
  State<SupplierStatementPage> createState() => _SupplierStatementPageState();
}

class _SupplierStatementPageState extends State<SupplierStatementPage> with SingleTickerProviderStateMixin {
  final _supplierRepository = SupplierRepository();
  final _invoiceRepository = InvoiceRepository();
  late final TabController _tabController;

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  bool _isLoading = true;
  Supplier? _supplier;
  SupplierStatement? _statement;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final supplier = await _supplierRepository.getSupplierByOfficialName(widget.hotel.id!, widget.companyName);
    if (supplier?.id == null) {
      if (!mounted) return;
      setState(() {
        _supplier = supplier;
        _isLoading = false;
      });
      return;
    }

    final invoices = await _invoiceRepository.getInvoicesBySupplier(hotelId: widget.hotel.id, companyName: widget.companyName);
    final statement = await _supplierRepository.buildStatement(supplierId: supplier!.id!, invoices: invoices);
    if (!mounted) return;
    setState(() {
      _supplier = supplier;
      _statement = statement;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat("#,##0.00");
    final hasSupplier = !_isLoading && _supplier?.id != null;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "بطاقة المورد", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: _identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: hasSupplier
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: "كشف الحساب"),
                  Tab(text: "مستندات المورد"),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _supplier?.id == null
              ? _buildNotFound()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSizes.md),
                        children: [
                          _buildSupplierHeader(),
                          const SizedBox(height: AppSizes.md),
                          _buildSummaryGrid(fmt),
                          const SizedBox(height: AppSizes.lg),
                          Text("العمليات", style: AppTextStyles.subtitle.copyWith(color: _identityColor, fontSize: 15)),
                          const SizedBox(height: AppSizes.sm),
                          if (_statement!.operations.isEmpty)
                            _buildEmptyOperations()
                          else
                            ..._statement!.operations.map((op) => Padding(
                                  padding: const EdgeInsets.only(bottom: AppSizes.sm),
                                  child: _buildOperationRow(op, fmt),
                                )),
                        ],
                      ),
                    ),
                    SupplierDocumentsTab(hotel: widget.hotel, supplier: _supplier!, identityColor: _identityColor),
                  ],
                ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: AppSizes.md),
            const Text("تعذّر العثور على سجل هذا المورد", style: AppTextStyles.bodyBold),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierHeader() {
    final s = _supplier!;
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _identityColor.withOpacity(0.1),
            child: Icon(Icons.business, color: _identityColor),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.officialName, style: AppTextStyles.title.copyWith(fontSize: 17)),
                Text("الرقم الضريبي: ${s.taxNumber}", style: AppTextStyles.caption),
                if (s.notes != null && s.notes!.isNotEmpty) Text(s.notes!, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(NumberFormat fmt) {
    final s = _statement!;
    final cards = <(String, String, IconData, Color?)>[
      ("عدد الفواتير", "${s.invoiceCount}", Icons.receipt_long, null),
      ("إجمالي قيمة الفواتير", "${fmt.format(s.totalInvoiced)} ريال", Icons.payments_outlined, null),
      ("إجمالي المسدد", "${fmt.format(s.totalPaid)} ريال", Icons.check_circle_outline, Colors.green),
      ("إجمالي المتبقي", "${fmt.format(s.totalRemaining)} ريال", Icons.hourglass_bottom_outlined, s.totalRemaining > 0 ? Colors.red : null),
      ("آخر فاتورة", s.lastInvoice == null ? "لا توجد" : "${s.lastInvoice!.invoiceNumber} — ${s.lastInvoice!.date}", Icons.history, null),
      ("آخر عملية سداد", s.lastPayment == null ? "لا توجد" : "${fmt.format(s.lastPayment!.amount)} — ${s.lastPayment!.date}", Icons.payment_outlined, null),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSizes.sm,
      crossAxisSpacing: AppSizes.sm,
      childAspectRatio: 1.9,
      children: cards.map((c) => _buildSummaryCard(c.$1, c.$2, c.$3, c.$4)).toList(),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color? valueColor) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _identityColor, size: 18),
          const Spacer(),
          Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: valueColor), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmptyOperations() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: AppSizes.sm),
            const Text("لا توجد عمليات مسجَّلة بعد لهذا المورد", style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationRow(SupplierStatementEntry op, NumberFormat fmt) {
    final color = op.isPayment ? Colors.green : _identityColor;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.xs),
        onTap: op.invoice == null
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailsPage(invoice: op.invoice!, hotel: widget.hotel))),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(op.isPayment ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 18),
        ),
        title: Text(op.label, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
        subtitle: Text(op.date, style: AppTextStyles.caption),
        trailing: Text(
          "${op.isPayment ? '-' : ''}${fmt.format(op.amount)} ريال",
          style: AppTextStyles.bodyBold.copyWith(color: color, fontSize: 13),
        ),
      ),
    );
  }
}
