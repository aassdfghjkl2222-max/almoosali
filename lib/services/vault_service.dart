import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/vault_repository.dart';
import '../models/vault_transaction.dart';
import '../core/app_colors.dart';
import '../core/app_radius.dart';

class VaultService {
  final _repository = VaultRepository();

  Future<bool> checkBalanceAndConfirm({
    required BuildContext context,
    required int hotelId,
    required double amount,
    required String source,
  }) async {
    if (source == 'خارج النظام') return true;

    final balances = await _repository.getBalances(hotelId);
    final balanceType = source == 'شبكة' ? 'bank' : 'cash';
    double currentBalance = balances[balanceType] ?? 0;

    if (currentBalance < amount) {
      if (context.mounted) {
        _showInsufficientBalanceDialog(context, currentBalance, amount);
      }
      return false;
    }

    if (!context.mounted) return false;
    final confirmed = await _showConfirmationDialog(context, amount, source);
    return confirmed;
  }

  Future<void> processVaultTransaction({
    required BuildContext context,
    required int hotelId,
    required double amount,
    required String source,
    required String type,
    required String reference,
    String? notes,
  }) async {
    if (source == 'خارج النظام') return;

    final balances = await _repository.getBalances(hotelId);
    final balanceType = source == 'شبكة' ? 'bank' : 'cash';
    double currentBalance = balances[balanceType] ?? 0;
    final newBalance = currentBalance - amount;

    final now = DateTime.now();
    final transaction = VaultTransaction(
      hotelId: hotelId,
      date: DateFormat('yyyy-MM-dd').format(now),
      time: DateFormat('HH:mm:ss').format(now),
      type: type,
      amount: amount,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      reference: reference,
      notes: notes,
      source: source,
    );

    await _repository.addTransaction(transaction);

    if (context.mounted) {
      _showUndoSnackBar(context, transaction);
    }
  }

  void _showInsufficientBalanceDialog(BuildContext context, double current, double required) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text("رصيد غير كافٍ", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(context, "الرصيد الحالي:", current),
            _buildInfoRow(context, "المبلغ المطلوب:", required),
            const Divider(height: 24),
            _buildInfoRow(context, "مقدار العجز:", required - current, color: AppColors.danger),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("إغلاق", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, double val, {Color? color}) {
    final format = NumberFormat("#,##0.##");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(
            format.format(val),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmationDialog(BuildContext context, double amount, String source) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("تأكيد العملية", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("سيتم خصم مبلغ ${NumberFormat("#,##0.##").format(amount)} من $source. هل أنت متأكد؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("إلغاء", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("تأكيد", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showUndoSnackBar(BuildContext context, VaultTransaction transaction) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("تم ترحيل الحركة المالية."),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        action: SnackBarAction(
          label: "تراجع",
          textColor: Theme.of(context).colorScheme.secondary,
          onPressed: () async {
            await _repository.undoTransaction(transaction);
          },
        ),
      ),
    );
  }
}
