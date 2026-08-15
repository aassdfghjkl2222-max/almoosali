import 'package:flutter_test/flutter_test.dart';
import 'package:manazel_new/data/supabase/models/supa_invoice.dart';
import 'package:manazel_new/data/supabase/models/supa_pending_expense.dart';
import 'package:manazel_new/data/supabase/models/supa_shared_expense.dart';
import 'package:manazel_new/data/supabase/models/supa_supplier.dart';

void main() {
  group('SupaSupplier', () {
    test('toInsertMap/toUpdateMap carry the right fields', () {
      const supplier = SupaSupplier(hotelId: 'h-1', officialName: 'شركة أ', shortName: 'أ', taxNumber: '300000000000003');
      expect(supplier.toInsertMap()['hotel_id'], 'h-1');
      expect(supplier.toUpdateMap().containsKey('hotel_id'), isFalse); // hotel never changes on update
    });

    test('isArchived reflects archivedAt', () {
      final archived = SupaSupplier.fromMap({
        'id': 's-1', 'hotel_id': 'h-1', 'official_name': 'a', 'short_name': 'a', 'tax_number': '1',
        'archived_at': '2026-07-01T00:00:00Z',
      });
      expect(archived.isArchived, isTrue);
    });
  });

  group('SupaInvoice', () {
    test('isDeferred is true only for deferred_supplier funding', () {
      final deferred = SupaInvoice.fromMap({
        'id': 'i-1', 'hotel_id': 'h-1', 'supplier_id': 's-1', 'invoice_number': '1', 'invoice_date': '2026-07-30',
        'amount_before_tax': 100, 'vat': 15, 'total_amount': 115, 'category_id': 'c-1',
        'funding_source_type': 'deferred_supplier',
      });
      expect(deferred.isDeferred, isTrue);

      final cash = SupaInvoice.fromMap({
        'id': 'i-2', 'hotel_id': 'h-1', 'supplier_id': 's-1', 'invoice_number': '2', 'invoice_date': '2026-07-30',
        'amount_before_tax': 100, 'vat': 15, 'total_amount': 115, 'category_id': 'c-1',
        'funding_source_type': 'hotel_safe',
      });
      expect(cash.isDeferred, isFalse);
    });
  });

  group('SupaPendingExpense', () {
    test('isFromSharedExpense reflects shared_expense_group_id', () {
      final fromShared = SupaPendingExpense.fromMap({
        'id': 'p-1', 'hotel_id': 'h-1', 'category_id': 'c-1', 'amount': 100, 'statement': 'x',
        'payment_method': 'cash', 'shared_expense_group_id': 'g-1',
      });
      expect(fromShared.isFromSharedExpense, isTrue);

      final standalone = SupaPendingExpense.fromMap({
        'id': 'p-2', 'hotel_id': 'h-1', 'category_id': 'c-1', 'amount': 100, 'statement': 'x',
        'payment_method': 'cash',
      });
      expect(standalone.isFromSharedExpense, isFalse);
    });
  });

  group('SupaSharedExpenseAllocation', () {
    test('toRpcJson omits statement when null, includes it when present', () {
      const withoutStatement = SupaSharedExpenseAllocation(sharedExpenseGroupId: 'g-1', hotelId: 'h-1', amount: 100);
      expect(withoutStatement.toRpcJson().containsKey('statement'), isFalse);

      const withStatement = SupaSharedExpenseAllocation(sharedExpenseGroupId: 'g-1', hotelId: 'h-1', amount: 100, statement: 'حصة الصيانة');
      expect(withStatement.toRpcJson()['statement'], 'حصة الصيانة');
    });
  });
}
