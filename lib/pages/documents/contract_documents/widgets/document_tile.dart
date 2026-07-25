import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_radius.dart';
import '../../../../core/app_sizes.dart';
import '../../../../core/app_text_styles.dart';
import '../../../../core/contract_document_options.dart';
import '../../../../models/contract_document.dart';
import '../../../../widgets/common/app_card.dart';

class DocumentTile extends StatelessWidget {
  final ContractDocument document;
  final bool isGrid;
  final VoidCallback onTap;
  const DocumentTile({super.key, required this.document, required this.isGrid, required this.onTap});

  bool get _isExpiringSoon {
    if (document.expiryDate == null) return false;
    final d = DateTime.tryParse(document.expiryDate!);
    if (d == null) return false;
    final days = d.difference(DateTime.now()).inDays;
    return days <= 30;
  }

  bool get _isExpired {
    if (document.expiryDate == null) return false;
    final d = DateTime.tryParse(document.expiryDate!);
    if (d == null) return false;
    return d.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final color = ContractFileTypes.colorFor(document.fileType);
    final icon = ContractFileTypes.iconFor(document.fileType);
    final expiryBadge = _isExpired
        ? const _ExpiryBadge(label: "منتهٍ", color: AppColors.danger)
        : (_isExpiringSoon ? const _ExpiryBadge(label: "قارب الانتهاء", color: AppColors.warning) : null);

    if (isGrid) {
      return AppCard(
        onTap: onTap,
        identityAccent: color,
        splashColor: color.withValues(alpha: 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                if (expiryBadge != null) expiryBadge,
              ],
            ),
            const Spacer(),
            Text(document.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(ContractFileTypes.labelFor(document.fileType), style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ],
        ),
      );
    }
    return AppCard(
      onTap: onTap,
      identityAccent: color,
      splashColor: color.withValues(alpha: 0.15),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(document.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(ContractFileTypes.labelFor(document.fileType), style: AppTextStyles.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
          if (expiryBadge != null) expiryBadge,
          const SizedBox(width: 4),
          const Icon(Icons.chevron_left_rounded, color: Colors.grey),
        ],
      ),
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ExpiryBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.xs)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
