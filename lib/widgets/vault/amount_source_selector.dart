import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';

class AmountSourceSelector extends StatelessWidget {
  final String selectedSource;
  final Function(String) onSourceChanged;

  const AmountSourceSelector({
    super.key,
    required this.selectedSource,
    required this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSourceItem(
                context: context,
                label: "الخزنة",
                icon: Icons.money,
                isSelected: selectedSource == 'الخزنة',
                onTap: () => onSourceChanged('الخزنة'),
                color: Colors.green,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: _buildSourceItem(
                context: context,
                label: "شبكة",
                icon: Icons.credit_card,
                isSelected: selectedSource == 'شبكة',
                onTap: () => onSourceChanged('شبكة'),
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: _buildSourceItem(
                context: context,
                label: "خارج النظام",
                icon: Icons.home_outlined,
                isSelected: selectedSource == 'خارج النظام',
                onTap: () => onSourceChanged('خارج النظام'),
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceItem({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
          ] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
