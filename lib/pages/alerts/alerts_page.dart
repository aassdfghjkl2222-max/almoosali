import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/document.dart';
import '../../models/hotel.dart';
import '../../repositories/document_repository.dart';
import '../../core/app_radius.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/hotel_identity_title.dart';

class AlertsPage extends StatefulWidget {
  final Hotel hotel;
  const AlertsPage({super.key, required this.hotel});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final _documentRepository = DocumentRepository();

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "التنبيهات العاجلة", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: AppDrawer(hotel: widget.hotel),
      body: FutureBuilder<List<Document>>(
        future: _documentRepository.getAllDocuments(widget.hotel.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }

          final allDocuments = snapshot.data ?? [];
          final alerts = _filterAlerts(allDocuments);

          if (alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: AppSizes.md),
                  Text(
                    "لا توجد تنبيهات عاجلة",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSizes.md),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.md),
                child: _buildAlertCard(alert),
              );
            },
          );
        },
      ),
    );
  }

  List<Document> _filterAlerts(List<Document> documents) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return documents.where((doc) {
      final expiry = DateTime.tryParse(doc.expiryDate);
      if (expiry == null) return false;
      
      final daysRemaining = expiry.difference(today).inDays;
      return daysRemaining <= 30; // تنبيه للمنتهي أو الذي ينتهي قريباً
    }).toList();
  }

  Widget _buildAlertCard(Document document) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime.tryParse(document.expiryDate);
    final days = expiry?.difference(today).inDays ?? 0;

    final color = days < 0 ? AppColors.danger : AppColors.warning;
    final statusText = days < 0 ? "منتهي" : "ينتهي قريباً ($days يوم)";

    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.warning_amber_rounded, color: color),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.name,
                  style: AppTextStyles.bodyBold,
                ),
                Text(
                  statusText,
                  style: AppTextStyles.caption.copyWith(color: color),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
