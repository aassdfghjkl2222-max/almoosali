import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/hotel.dart';
import '../../../models/relationship_txn.dart';
import '../../../repositories/financial_relationships_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../widgets/common/app_card.dart';
import 'relationship_txn_list_page.dart';

class _CounterpartyRow {
  final String key;
  final String name;
  final int hotelId;
  final double receivable;
  final double payable;
  final String? lastDate;
  final int opCount;
  const _CounterpartyRow(this.key, this.name, this.hotelId, this.receivable, this.payable, this.lastDate, this.opCount);
  double get net => receivable - payable;
}

/// قسم "العلاقات المالية" داخل مركز التحليل — قراءة فقط بالكامل. يعرض
/// العلاقات المالية بين الفنادق والأشخاص والموردين، بأرصدة حقيقية من
/// FinancialEngine ونظام التسويات معاً (بلا دمج للنظامين، فقط قراءة موحّدة).
class RelationshipsCenterPage extends StatefulWidget {
  final Hotel hotel;
  final String? initialRelationTypeFilter; // null | 'hotel' | 'person' | 'supplier'
  const RelationshipsCenterPage({super.key, required this.hotel, this.initialRelationTypeFilter});

  @override
  State<RelationshipsCenterPage> createState() => _RelationshipsCenterPageState();
}

class _RelationshipsCenterPageState extends State<RelationshipsCenterPage> {
  final _repo = FinancialRelationshipsRepository();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<Hotel> _allHotels = [];
  Map<int, String> _hotelNames = {};

  List<_CounterpartyRow> _hotelRows = [];
  List<_CounterpartyRow> _personRows = [];
  List<_CounterpartyRow> _supplierRows = [];

  List<RelationshipTxn> _allHotelTxns = [];
  List<RelationshipTxn> _allPersonTxns = [];
  List<RelationshipTxn> _allSupplierTxns = [];

  String _searchQuery = "";
  String? _relationTypeFilter; // null | 'hotel' | 'person' | 'supplier'
  bool? _statusOpenFilter; // null=الكل، true=مفتوحة فقط، false=مسدَّدة فقط

  @override
  void initState() {
    super.initState();
    _relationTypeFilter = widget.initialRelationTypeFilter;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _allHotels = await HotelRepository().getAllHotels();
    _hotelNames = {for (final h in _allHotels) if (h.id != null) h.id!: h.arabicName};

    final results = await Future.wait([
      _repo.getHotelBalances(_hotelNames),
      _repo.getCounterpartyBalances('person', _hotelNames),
      _repo.getCounterpartyBalances('supplier', _hotelNames),
      _repo.getHotelToHotelTxns(_hotelNames),
      _repo.getPersonTxns(_hotelNames),
      _repo.getSupplierTxns(_hotelNames),
    ]);

    final hotelBalances = results[0] as Map<int, Map<String, double>>;
    final personBalances = results[1] as Map<String, Map<String, dynamic>>;
    final supplierBalances = results[2] as Map<String, Map<String, dynamic>>;
    _allHotelTxns = results[3] as List<RelationshipTxn>;
    _allPersonTxns = results[4] as List<RelationshipTxn>;
    _allSupplierTxns = results[5] as List<RelationshipTxn>;

    _hotelRows = hotelBalances.entries
        .where((e) => e.value['receivable']! > 0 || e.value['payable']! > 0)
        .map((e) => _CounterpartyRow("hotel|${e.key}", _hotelNames[e.key] ?? 'فندق #${e.key}', e.key, e.value['receivable']!, e.value['payable']!, null, 0))
        .toList()
      ..sort((a, b) => b.net.abs().compareTo(a.net.abs()));

    _personRows = personBalances.values
        .map((v) => _CounterpartyRow("person|${v['hotelId']}|${v['name']}", v['name'] as String, v['hotelId'] as int, v['receivable'] as double, v['payable'] as double, v['lastDate'] as String?, v['opCount'] as int))
        .toList()
      ..sort((a, b) => b.net.abs().compareTo(a.net.abs()));

    _supplierRows = supplierBalances.values
        .map((v) => _CounterpartyRow("supplier|${v['hotelId']}|${v['name']}", v['name'] as String, v['hotelId'] as int, v['receivable'] as double, v['payable'] as double, v['lastDate'] as String?, v['opCount'] as int))
        .toList()
      ..sort((a, b) => b.net.abs().compareTo(a.net.abs()));

    if (mounted) setState(() => _isLoading = false);
  }

  Hotel _hotelFor(int id) => _allHotels.firstWhere((h) => h.id == id, orElse: () => widget.hotel);

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  double get _totalPayable => _hotelRows.fold(0.0, (s, r) => s + r.payable) + _personRows.fold(0.0, (s, r) => s + r.payable) + _supplierRows.fold(0.0, (s, r) => s + r.payable);
  double get _totalReceivable => _hotelRows.fold(0.0, (s, r) => s + r.receivable) + _personRows.fold(0.0, (s, r) => s + r.receivable) + _supplierRows.fold(0.0, (s, r) => s + r.receivable);
  int get _debtorCount => [..._hotelRows, ..._personRows, ..._supplierRows].where((r) => r.payable > 0).length;
  int get _creditorCount => [..._hotelRows, ..._personRows, ..._supplierRows].where((r) => r.receivable > 0).length;
  double get _maxDebt => [..._hotelRows, ..._personRows, ..._supplierRows].map((r) => r.payable).fold(0.0, (a, b) => a > b ? a : b);
  double get _maxReceivable => [..._hotelRows, ..._personRows, ..._supplierRows].map((r) => r.receivable).fold(0.0, (a, b) => a > b ? a : b);

  List<RelationshipTxn> get _allTxns => [..._allHotelTxns, ..._allPersonTxns, ..._allSupplierTxns];

  List<RelationshipTxn> _filteredTxns(List<RelationshipTxn> source, {String? relationType}) {
    return source.where((t) {
      if (relationType != null && t.counterpartyType != relationType) return false;
      if (_relationTypeFilter != null && t.counterpartyType != _relationTypeFilter) return false;
      if (_statusOpenFilter != null) {
        final isOpen = t.status == 'مفتوحة';
        if (_statusOpenFilter! != isOpen) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = t.counterpartyName.toLowerCase().contains(q) ||
            t.hotelName.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q) ||
            t.id.toString() == q ||
            DateFormat('yyyy-MM-dd').format(t.date).contains(q) ||
            t.amount.toString().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _openTxnList(String title, List<RelationshipTxn> txns, Color color) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RelationshipTxnListPage(contextHotel: widget.hotel, title: title, txns: txns, color: color)));
  }

  void _openFilterSheet() {
    String? relationType = _relationTypeFilter;
    bool? statusOpen = _statusOpenFilter;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("فلاتر العلاقات المالية", style: AppTextStyles.title.copyWith(fontSize: 18)),
              const SizedBox(height: AppSizes.md),
              Text("نوع العلاقة", style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
              const SizedBox(height: AppSizes.sm),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text("الكل", style: TextStyle(fontSize: 12)), selected: relationType == null, onSelected: (_) => setSheetState(() => relationType = null)),
                ChoiceChip(label: const Text("فنادق", style: TextStyle(fontSize: 12)), selected: relationType == 'hotel', onSelected: (_) => setSheetState(() => relationType = 'hotel')),
                ChoiceChip(label: const Text("أشخاص", style: TextStyle(fontSize: 12)), selected: relationType == 'person', onSelected: (_) => setSheetState(() => relationType = 'person')),
                ChoiceChip(label: const Text("موردون", style: TextStyle(fontSize: 12)), selected: relationType == 'supplier', onSelected: (_) => setSheetState(() => relationType = 'supplier')),
              ]),
              const SizedBox(height: AppSizes.md),
              Text("الحالة", style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
              const SizedBox(height: AppSizes.sm),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text("الكل", style: TextStyle(fontSize: 12)), selected: statusOpen == null, onSelected: (_) => setSheetState(() => statusOpen = null)),
                ChoiceChip(label: const Text("مفتوحة", style: TextStyle(fontSize: 12)), selected: statusOpen == true, onSelected: (_) => setSheetState(() => statusOpen = true)),
                ChoiceChip(label: const Text("مسدَّدة", style: TextStyle(fontSize: 12)), selected: statusOpen == false, onSelected: (_) => setSheetState(() => statusOpen = false)),
              ]),
              const SizedBox(height: AppSizes.lg),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: HotelVisualIdentity.colorForHotel(widget.hotel), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                onPressed: () {
                  setState(() {
                    _relationTypeFilter = relationType;
                    _statusOpenFilter = statusOpen;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text("تطبيق"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        title: const Text("العلاقات المالية", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildSearchBar(identityColor),
                const SizedBox(height: AppSizes.sm),
                _buildFilterButton(identityColor),
                const SizedBox(height: AppSizes.lg),
                _buildSummaryGrid(identityColor),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("العلاقات بين الفنادق"),
                const SizedBox(height: AppSizes.sm),
                if (_relationTypeFilter == null || _relationTypeFilter == 'hotel') ..._buildRelationRows(_hotelRows, 'hotel', identityColor),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("العلاقات مع الأشخاص"),
                const SizedBox(height: AppSizes.sm),
                if (_relationTypeFilter == null || _relationTypeFilter == 'person') ..._buildRelationRows(_personRows, 'person', identityColor),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("العلاقات مع الموردين"),
                const SizedBox(height: AppSizes.sm),
                if (_relationTypeFilter == null || _relationTypeFilter == 'supplier') ..._buildRelationRows(_supplierRows, 'supplier', identityColor),
                const SizedBox(height: AppSizes.xl),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15));
  }

  Widget _buildSearchBar(Color color) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
      decoration: InputDecoration(
        hintText: "بحث باسم فندق/شخص/مورد أو رقم عملية أو تاريخ أو مبلغ...",
        hintStyle: AppTextStyles.caption,
        prefixIcon: Icon(Icons.search, color: color),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: color.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: color.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: color)),
      ),
    );
  }

  Widget _buildFilterButton(Color color) {
    final hasFilter = _relationTypeFilter != null || _statusOpenFilter != null;
    return InkWell(
      onTap: _openFilterSheet,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: color.withOpacity(0.25))),
        child: Row(
          children: [
            Icon(Icons.tune, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(hasFilter ? "فلاتر مطبَّقة" : "بلا فلاتر", style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
            if (hasFilter)
              TextButton(
                onPressed: () => setState(() {
                  _relationTypeFilter = null;
                  _statusOpenFilter = null;
                }),
                child: const Text("مسح", style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(Color color) {
    final items = [
      ("إجمالي الديون", _format(_totalPayable), AppColors.danger, () => _openTxnList("كل الديون (عليها)", _filteredTxns(_allTxns).where((t) => !t.isReceivable).toList(), color)),
      ("إجمالي المستحقات", _format(_totalReceivable), AppColors.success, () => _openTxnList("كل المستحقات (لها)", _filteredTxns(_allTxns).where((t) => t.isReceivable).toList(), color)),
      ("صافي العلاقات المالية", _format(_totalReceivable - _totalPayable), color, () => _openTxnList("كل العمليات", _filteredTxns(_allTxns), color)),
      ("عدد الجهات المدينة", "$_debtorCount", AppColors.warning, null),
      ("عدد الجهات الدائنة", "$_creditorCount", AppColors.info, null),
      ("أكبر مديونية", _format(_maxDebt), AppColors.danger, null),
      ("أكبر مستحق", _format(_maxReceivable), AppColors.success, null),
    ];
    return _buildStaticGrid(items.map((i) => _summaryCard(i.$1, i.$2, i.$3, i.$4)).toList(), columns: 2);
  }

  Widget _summaryCard(String label, String value, Color color, VoidCallback? onTap) {
    return AppCard(
      onTap: onTap ?? () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.title.copyWith(fontSize: 17, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  List<Widget> _buildRelationRows(List<_CounterpartyRow> rows, String type, Color identityColor) {
    final filtered = _searchQuery.isEmpty ? rows : rows.where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    if (filtered.isEmpty) {
      return [const Padding(padding: EdgeInsets.all(16), child: Center(child: Text("لا توجد علاقات مسجلة", style: AppTextStyles.caption)))];
    }
    return filtered.map((r) {
      final color = HotelVisualIdentity.colorForHotel(_hotelFor(r.hotelId));
      return Card(
        margin: const EdgeInsets.only(bottom: AppSizes.sm),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(type == 'hotel' ? Icons.apartment_outlined : (type == 'person' ? Icons.person_outline : Icons.local_shipping_outlined), color: color, size: 18),
          ),
          title: Text(r.name, style: AppTextStyles.bodyBold),
          subtitle: Text("له: ${_format(r.receivable)}   عليه: ${_format(r.payable)}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_format(r.net), style: AppTextStyles.bodyBold.copyWith(color: r.net >= 0 ? AppColors.success : AppColors.danger)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
            ],
          ),
          onTap: () {
            final source = type == 'hotel' ? _allHotelTxns : (type == 'person' ? _allPersonTxns : _allSupplierTxns);
            final txns = source.where((t) => t.hotelId == r.hotelId && t.counterpartyName == r.name).toList()..sort((a, b) => b.date.compareTo(a.date));
            _openTxnList(r.name, txns, color);
          },
        ),
      );
    }).toList();
  }

  Widget _buildStaticGrid(List<Widget> items, {required int columns, double spacing = 12}) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += columns) {
      final rowChildren = <Widget>[];
      for (int c = 0; c < columns; c++) {
        final idx = i + c;
        if (c > 0) rowChildren.add(SizedBox(width: spacing));
        rowChildren.add(Expanded(child: idx < items.length ? items[idx] : const SizedBox()));
      }
      rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowChildren)));
      if (i + columns < items.length) rows.add(SizedBox(height: spacing));
    }
    return Column(children: rows);
  }
}
