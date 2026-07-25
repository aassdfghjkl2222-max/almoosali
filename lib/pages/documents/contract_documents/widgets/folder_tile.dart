import 'package:flutter/material.dart';

import '../../../../core/app_radius.dart';
import '../../../../core/app_sizes.dart';
import '../../../../core/app_text_styles.dart';
import '../../../../core/contract_document_options.dart';
import '../../../../models/contract_folder.dart';
import '../../../../widgets/common/app_card.dart';

class FolderTile extends StatelessWidget {
  final ContractFolder folder;
  final bool isGrid;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const FolderTile({super.key, required this.folder, required this.isGrid, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final color = Color(folder.colorValue);
    final icon = ContractFolderIcons.iconFor(folder.iconKey);
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
                if (onLongPress != null)
                  InkWell(borderRadius: BorderRadius.circular(20), onTap: onLongPress, child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey))),
              ],
            ),
            const Spacer(),
            Text(folder.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (folder.description != null && folder.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(folder.description!, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
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
                Text(folder.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (folder.description != null && folder.description!.trim().isNotEmpty)
                  Text(folder.description!, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (onLongPress != null) InkWell(borderRadius: BorderRadius.circular(20), onTap: onLongPress, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey))),
          const Icon(Icons.chevron_left_rounded, color: Colors.grey),
        ],
      ),
    );
  }
}
