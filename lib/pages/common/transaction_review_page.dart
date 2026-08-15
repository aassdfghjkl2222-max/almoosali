import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';

class ReviewItem {
  final String label;
  final String value;
  final Color? color;
  final bool isHeader;

  ReviewItem({required this.label, required this.value, this.color, this.isHeader = false});
}

class TransactionReviewPage extends StatelessWidget {
  final String title;
  final List<ReviewItem> items;
  final Future<void> Function() onConfirm;
  final String confirmLabel;

  const TransactionReviewPage({
    super.key,
    required this.title,
    required this.items,
    required this.onConfirm,
    this.confirmLabel = "تأكيد العملية",
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            Expanded(
              child: AppCard(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item.isHeader) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          item.label,
                          style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.label, style: AppTextStyles.body.copyWith(color: Colors.grey)),
                        Text(
                          item.value,
                          style: AppTextStyles.bodyBold.copyWith(color: item.color),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: "✏️ تعديل",
                    onPressed: () => Navigator.pop(context),
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: AppButton(
                    text: "✅ $confirmLabel",
                    onPressed: () async {
                      try {
                        await onConfirm();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceFirst('StateError: ', '')), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
          ],
        ),
      ),
    );
  }
}
