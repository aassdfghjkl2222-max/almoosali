import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/settlement.dart';
import '../../../models/hotel.dart';
import '../../../repositories/settlement_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../widgets/common/app_card.dart';
import 'add_inter_entity_debt_page.dart';
import 'inter_entity_debt_details_page.dart';

import '../../../core/hotel_visual_identity.dart';

class InterEntityDebtsPage extends StatefulWidget {
  final Hotel hotel;
  const InterEntityDebtsPage({super.key, required this.hotel});

  @override
  State<InterEntityDebtsPage> createState() => _InterEntityDebtsPageState();
}

class _InterEntityDebtsPageState extends State<InterEntityDebtsPage> {
  final _repository = SettlementRepository();
  final _hotelRepository = HotelRepository();
  
  List<Settlement> _settlements = [];
  List<Hotel> _hotels = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _sortBy = "الأحدث";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final settlements = await _repository.getSettlements(
        type: 'inter_entity', 
        hotelId: widget.hotel.id!
      );
      final hotels = await _hotelRepository.getAllHotelsIncludingArchived();
      setState(() {
        _settlements = settlements;
        _hotels = hotels;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في تحميل البيانات: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Settlement> get _filteredSettlements {
    List<Settlement> list = _settlements.where((s) {
      final creditor = _getHotelName(s.creditorHotelId);
      final debtor = _getHotelName(s.debtorHotelId);
      final matchesSearch = s.description.contains(_searchQuery) || 
                            creditor.contains(_searchQuery) || 
                            debtor.contains(_searchQuery);
      return matchesSearch;
    }).toList();

    if (_sortBy == "الأحدث") {
      list.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sortBy == "الأقدم") {
      list.sort((a, b) => a.date.compareTo(b.date));
    } else if (_sortBy == "المبلغ") {
      list.sort((a, b) => b.amount.compareTo(a.amount));
    }

    return list;
  }

  String _getHotelName(int? id) {
    if (id == null) return "غير معروف";
    final hotel = _hotels.firstWhere((h) => h.id == id, orElse: () => Hotel(arabicName: "غير معروف", englishName: "", city: ""));
    return hotel.arabicName;
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("الديون بين المنشآت", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredSettlements.isEmpty 
                ? const Center(child: Text("لا توجد مديونيات مضافة"))
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.md),
                    itemCount: _filteredSettlements.length,
                    itemBuilder: (context, index) {
                      final settlement = _filteredSettlements[index];
                      return _buildDebtCard(settlement);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddInterEntityDebtPage(hotel: widget.hotel)),
          );
          if (result == true) _loadData();
        },
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: "بحث عن مديونية...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.md)),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Text("ترتيب حسب: "),
              const SizedBox(width: AppSizes.sm),
              DropdownButton<String>(
                value: _sortBy,
                items: ["الأحدث", "الأقدم", "المبلغ"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _sortBy = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(Settlement settlement) {
    final isPaid = settlement.status == 'paid';
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: AppCard(
        identityAccent: identityColor,
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InterEntityDebtDetailsPage(hotel: widget.hotel, settlement: settlement)),
          );
          if (result == true) _loadData();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${settlement.date.day}/${settlement.date.month}/${settlement.date.year}",
                  style: AppTextStyles.caption,
                ),
                _buildStatusTag(settlement.status),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("الدائن", style: AppTextStyles.caption),
                      Text(_getHotelName(settlement.creditorHotelId), style: AppTextStyles.bodyBold),
                    ],
                  ),
                ),
                Icon(Icons.arrow_back, color: identityColor, size: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("المدين", style: AppTextStyles.caption),
                      Text(_getHotelName(settlement.debtorHotelId), style: AppTextStyles.bodyBold),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("المبلغ", style: AppTextStyles.caption),
                    Text("${NumberFormat("#,##0.00").format(settlement.amount)} ريال", style: AppTextStyles.title.copyWith(color: identityColor)),
                  ],
                ),
                if (!isPaid)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("المتبقي", style: AppTextStyles.caption),
                      Text("${NumberFormat("#,##0.00").format(settlement.remainingAmount)} ريال", style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    final isPaid = status == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isPaid ? "مسددة" : "مفتوحة",
        style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
