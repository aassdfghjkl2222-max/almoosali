import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/settlement_account.dart';
import '../../../repositories/settlement_repository.dart';
import '../../../widgets/common/app_card.dart';
import 'person_account_details_page.dart';
import 'add_person_operation_page.dart';

import '../../../core/hotel_visual_identity.dart';
import '../../../models/hotel.dart';

class PersonDebtsPage extends StatefulWidget {
  final Hotel hotel;
  const PersonDebtsPage({super.key, required this.hotel});

  @override
  State<PersonDebtsPage> createState() => _PersonDebtsPageState();
}

class _PersonDebtsPageState extends State<PersonDebtsPage> {
  final _repository = SettlementRepository();
  
  List<SettlementAccount> _accounts = [];
  Map<String, dynamic> _summary = {
    'totalDueToMe': 0.0,
    'totalIOwe': 0.0,
    'accountCount': 0,
  };
  bool _isLoading = true;
  String _searchQuery = "";
  String _sortBy = "الاسم";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _repository.getAccounts(widget.hotel.id!, type: 'person');
      final summary = await _repository.getOverallSummary(widget.hotel.id!, 'person');
      setState(() {
        _accounts = accounts;
        _summary = summary;
      });
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<SettlementAccount> get _filteredAccounts {
    List<SettlementAccount> list = _accounts.where((a) {
      return a.name.contains(_searchQuery);
    }).toList();

    if (_sortBy == "الاسم") {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == "الأحدث") {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("ديون الأشخاص", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSummaryHeader(identityColor),
          _buildSearchBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredAccounts.isEmpty 
                ? const Center(child: Text("لا توجد حسابات مضافة"))
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.md),
                    itemCount: _filteredAccounts.length,
                    itemBuilder: (context, index) {
                      final account = _filteredAccounts[index];
                      return _buildAccountCard(account);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddPersonOperationPage(hotel: widget.hotel)),
          );
          if (result == true) _loadData();
        },
        label: const Text("إضافة شخص أو عملية"),
        icon: const Icon(Icons.add),
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummaryHeader(Color identityColor) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: identityColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.lg),
          bottomRight: Radius.circular(AppSizes.lg),
        ),
      ),
      child: Row(
        children: [
          _buildSummaryItem("مستحق لك", _summary['totalDueToMe'], Colors.greenAccent),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildSummaryItem("مستحق عليك", _summary['totalIOwe'], Colors.orangeAccent),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildSummaryItem("الحسابات", _summary['accountCount'].toDouble(), Colors.white, isAmount: false),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color, {bool isAmount = true}) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            isAmount ? NumberFormat("#,##0").format(value) : value.toInt().toString(),
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "بحث عن شخص...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.md), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (context) => [
              const PopupMenuItem(value: "الاسم", child: Text("الاسم")),
              const PopupMenuItem(value: "الأحدث", child: Text("الأحدث")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(SettlementAccount account) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: AppCard(
        identityAccent: identityColor,
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PersonAccountDetailsPage(hotel: widget.hotel, account: account)),
          );
          if (result == true) _loadData();
        },
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: identityColor.withOpacity(0.1),
              child: Text(account.name[0], style: TextStyle(color: identityColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name, style: AppTextStyles.bodyBold),
                  Text("تم الإنشاء في: ${account.createdAt.day}/${account.createdAt.month}/${account.createdAt.year}", 
                       style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
