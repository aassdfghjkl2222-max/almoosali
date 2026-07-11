import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/hotel.dart';
import '../../../services/financial_engine.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';

class VaultTransactionsPage extends StatefulWidget {
  final Hotel hotel;
  const VaultTransactionsPage({super.key, required this.hotel});

  @override
  State<VaultTransactionsPage> createState() => _VaultTransactionsPageState();
}

class _VaultTransactionsPageState extends State<VaultTransactionsPage> {
  final _engine = FinancialEngine();
  List<Map<String, dynamic>> _allEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  bool _isLoading = true;
  
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = "";
  String? _selectedType; // 'debit' or 'credit'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _engine.getLedger(widget.hotel.id!, 'all');
    if (mounted) setState(() {
      _allEntries = data;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredEntries = _allEntries.where((e) {
        // 1. Search Query
        final matchesSearch = _searchQuery.isEmpty || 
            e['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (e['reference_type']?.toString().contains(_searchQuery) ?? false);
        
        // 2. Date Range
        DateTime entryDate = DateTime.tryParse(e['date']) ?? DateTime.now();
        final matchesDate = (_startDate == null || entryDate.isAfter(_startDate!.subtract(const Duration(days: 1)))) &&
                          (_endDate == null || entryDate.isBefore(_endDate!.add(const Duration(days: 1))));

        // 3. Transaction Type
        final matchesType = _selectedType == null || e['type'] == _selectedType;

        return matchesSearch && matchesDate && matchesType;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDateRange: _startDate != null && _endDate != null 
          ? DateTimeRange(start: _startDate!, end: _endDate!) 
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  String _format(num val) => NumberFormat("#,##0.##").format(val);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "سجل الحركات الشامل", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          if (_startDate != null || _endDate != null || _selectedType != null || _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _selectedType = null;
                  _searchQuery = "";
                });
                _applyFilters();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredEntries.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSizes.md),
                      itemCount: _filteredEntries.length,
                      itemBuilder: (context, index) {
                        return _buildTransactionItem(_filteredEntries[index], identityColor);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      color: Colors.white,
      child: TextField(
        onChanged: (v) {
          _searchQuery = v;
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: "بحث في البيان، المرجع...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: const Text("كل الحركات"),
            selected: _selectedType == null,
            onSelected: (val) {
              if (val) setState(() => _selectedType = null);
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text("مدين (Debit)"),
            selected: _selectedType == 'debit',
            onSelected: (val) {
              if (val) setState(() => _selectedType = 'debit');
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text("دائن (Credit)"),
            selected: _selectedType == 'credit',
            onSelected: (val) {
              if (val) setState(() => _selectedType = 'credit');
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> e, Color identityColor) {
    final isDebit = e['type'] == 'debit';
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      identityAccent: identityColor,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.receipt_outlined, color: Colors.blueGrey, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e['description'], style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                    Text("${e['date']} • ${e['time']}", style: AppTextStyles.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_format(e['amount']), style: AppTextStyles.bodyBold.copyWith(color: Theme.of(context).colorScheme.primary)),
                  Text(isDebit ? "مدين (Debit)" : "دائن (Credit)", style: TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniInfo("قبل", _format(e['balance_before'])),
              _miniInfo("بعد", _format(e['balance_after'])),
              _miniInfo("مرجع", "#${e['reference_id'] ?? '---'}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        Text(val, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("لا توجد حركات تطابق الفلترة الحالية", style: TextStyle(color: Colors.grey)),
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
                _selectedType = null;
                _searchQuery = "";
              });
              _applyFilters();
            },
            child: const Text("مسح كل الفلاتر"),
          ),
        ],
      ),
    );
  }
}
