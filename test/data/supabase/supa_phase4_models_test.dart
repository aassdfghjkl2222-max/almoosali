import 'package:flutter_test/flutter_test.dart';
import 'package:manazel_new/data/supabase/models/supa_contract.dart';
import 'package:manazel_new/data/supabase/models/supa_contract_document.dart';
import 'package:manazel_new/data/supabase/models/supa_employee.dart';
import 'package:manazel_new/data/supabase/models/supa_payroll.dart';

void main() {
  group('SupaEmployee', () {
    test('toInsertMap never includes employee_number (database-generated)', () {
      const employee = SupaEmployee(hotelId: 'h-1', name: 'أحمد', position: 'استقبال', salary: 4000, hiredAt: '2026-01-01');
      expect(employee.toInsertMap().containsKey('employee_number'), isFalse);
    });

    test('toUpdateMap never includes hotel_id (an employee never changes hotel)', () {
      const employee = SupaEmployee(id: 'e-1', hotelId: 'h-1', name: 'أحمد', position: 'استقبال', salary: 4000, hiredAt: '2026-01-01');
      expect(employee.toUpdateMap().containsKey('hotel_id'), isFalse);
    });
  });

  group('SupaPayrollRecord', () {
    test('fromMap defaults optional numeric fields to zero, not null-crash', () {
      final record = SupaPayrollRecord.fromMap({
        'id': 'p-1', 'hotel_id': 'h-1', 'employee_id': 'e-1', 'period': '2026-07',
        'base_salary': 4000, 'net_salary': 3900,
      });
      expect(record.allowancesTotal, 0);
      expect(record.advancesTotal, 0);
      expect(record.totalDaysInPeriod, 30);
    });
  });

  group('SupaContract', () {
    test('status defaults to active', () {
      const contract = SupaContract(
        hotelId: 'h-1', name: 'عقد', contractorName: 'شركة', startDate: '2026-01-01',
        duration: 'سنة', endDate: '2026-12-31', totalValue: 1000, paymentMethod: 'شهري',
      );
      expect(contract.status, SupaContract.statusActive);
      expect(contract.isArchived, isFalse);
    });
  });

  group('SupaContractDocumentFolder', () {
    test('isCompanyWide is true only when hotelId is null', () {
      const companyWide = SupaContractDocumentFolder(name: 'عام');
      expect(companyWide.isCompanyWide, isTrue);

      const hotelScoped = SupaContractDocumentFolder(name: 'خاص', hotelId: 'h-1');
      expect(hotelScoped.isCompanyWide, isFalse);
    });
  });
}
