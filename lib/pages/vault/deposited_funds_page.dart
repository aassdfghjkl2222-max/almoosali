import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/deposited_fund.dart';
import '../../../repositories/vault_repository.dart';
import '../../../widgets/common/app_card.dart';
import '../../../models/hotel.dart';
import '../../../widgets/common/hotel_identity_title.dart';

class DepositedFundsPage extends StatefulWidget {
  final Hotel hotel;
  final bool isArchive;
  const DepositedFundsPage({super.key, required this.hotel, this.isArchive = false});

  @override
  State<DepositedFundsPage> createState() => _DepositedFundsPageState();
}

class _DepositedFundsPageState extends State<DepositedFundsPage> {
  final _repository = VaultRepository();
  List<DepositedFund> _funds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final funds = await _repository.getDepositedFunds(
      hotelId: widget.hotel.id!, 
      isArchived: widget.isArchive
    );
    if (mounted) {
      setState(() {
        _funds = funds;
        _isLoading = false;
      });
    }
  }

  String _format(double amount) => NumberFormat("#,##0.##").format(amount);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(
          title: widget.isArchive ? "أرشيف الأموال المرحلة" : "الأموال المودعة",
          hotel: widget.hotel
        ),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _funds.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: _funds.length,
                  itemBuilder: (context, index) => _buildArchiveCard(_funds[index]),
                ),
    );
  }

  Widget _buildArchiveCard(DepositedFund fund) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fund.date, style: AppTextStyles.bodyBold),
              const Row(
                children: [
                   Icon(Icons.check_circle, color: Colors.green, size: 16),
                   SizedBox(width: 4),
                   Text("تم الترحيل بالكامل", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _amountCol("النقد المرحل", fund.cashAmount, Colors.blue),
              _amountCol("البنك المرحل", fund.networkAmount, Colors.purple),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.blueGrey),
                SizedBox(width: 8),
                Expanded(child: Text("تم الاعتماد بواسطة: مدير النظام", style: TextStyle(fontSize: 10, color: Colors.blueGrey))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountCol(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(_format(val), style: AppTextStyles.bodyBold.copyWith(color: color, fontSize: 16)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text("لا توجد بيانات مؤرشفة حالياً", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
