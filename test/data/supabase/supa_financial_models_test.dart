import 'package:flutter_test/flutter_test.dart';
import 'package:manazel_new/data/supabase/models/supa_financial_category.dart';
import 'package:manazel_new/data/supabase/models/supa_financial_report.dart';

void main() {
  group('SupaFinancialCategory', () {
    test('fromMap reads every column with the right defaults for optional fields', () {
      final category = SupaFinancialCategory.fromMap({
        'id': 'cat-1',
        'name': 'كهرباء',
        'code': null,
        'type': 'expense',
        'parent_id': null,
        'icon_code': 0xe1ff,
        'color_value': 0xFFFF0000,
        'description': null,
        'sort_order': 3,
        'is_pinned': true,
        'is_default': false,
        'usage_count': 7,
        'last_used_at': '2026-07-28T10:00:00Z',
        'archived_at': null,
        'archived_by': null,
        'created_at': '2026-07-01T00:00:00Z',
        'updated_at': null,
        'created_by': 'user-1',
        'updated_by': null,
      });

      expect(category.id, 'cat-1');
      expect(category.name, 'كهرباء');
      expect(category.type, 'expense');
      expect(category.isExpense, isTrue);
      expect(category.isRevenue, isFalse);
      expect(category.isPinned, isTrue);
      expect(category.isArchived, isFalse);
      expect(category.usageCount, 7);
      expect(category.sortOrder, 3);
    });

    test('archivedAt non-null makes isArchived true', () {
      final category = SupaFinancialCategory.fromMap({
        'id': 'cat-2',
        'name': 'مياه',
        'type': 'expense',
        'icon_code': 1,
        'color_value': 1,
        'archived_at': '2026-07-20T00:00:00Z',
      });
      expect(category.isArchived, isTrue);
    });

    test('toInsertMap never includes id/created_at/updated_at (database-managed)', () {
      const category = SupaFinancialCategory(name: 'وقود', type: 'expense', iconCode: 1, colorValue: 1);
      final map = category.toInsertMap();
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('created_at'), isFalse);
      expect(map.containsKey('updated_at'), isFalse);
      expect(map['name'], 'وقود');
      expect(map['type'], 'expense');
    });

    test('toUpdateMap never includes type (immutable after creation, mirrors the local SQLite repository)', () {
      const category = SupaFinancialCategory(id: 'cat-3', name: 'وقود', type: 'expense', iconCode: 1, colorValue: 1);
      expect(category.toUpdateMap().containsKey('type'), isFalse);
    });

    test('copyWith(clearParentId: true) actually nulls parentId, not just skips it', () {
      const category = SupaFinancialCategory(id: 'cat-4', name: 'a', type: 'expense', parentId: 'parent-1', iconCode: 1, colorValue: 1);
      final cleared = category.copyWith(clearParentId: true);
      expect(cleared.parentId, isNull);
    });
  });

  group('SupaFinancialReport', () {
    test('netProfit is income minus expense', () {
      final report = SupaFinancialReport.fromMap({
        'id': 'r-1',
        'hotel_id': 'h-1',
        'report_date': '2026-07-28',
        'report_type': 'main',
        'income_total': 1780.0,
        'expense_total': 120.5,
        'is_posted': false,
        'is_locked': false,
      });
      expect(report.netProfit, closeTo(1659.5, 0.001));
    });
  });

  group('SupaFinancialReportRevenueLine', () {
    test('toRpcJson omits notes when null, includes it when present', () {
      const withoutNotes = SupaFinancialReportRevenueLine(reportId: 'r-1', categoryId: 'c-1', amount: 100, paymentMethod: 'cash');
      expect(withoutNotes.toRpcJson().containsKey('notes'), isFalse);

      const withNotes = SupaFinancialReportRevenueLine(reportId: 'r-1', categoryId: 'c-1', amount: 100, paymentMethod: 'cash', notes: 'حجز إضافي');
      expect(withNotes.toRpcJson()['notes'], 'حجز إضافي');
    });
  });

  group('SupaFinancialReportIncomeBreakdown', () {
    test('total sums all five components', () {
      const breakdown = SupaFinancialReportIncomeBreakdown(
        reportId: 'r-1',
        roomCash: 1000,
        roomPos: 250,
        roomBankTransfer: 0,
        parkingCash: 30,
        parkingPos: 0,
      );
      expect(breakdown.total, 1280);
    });
  });
}
