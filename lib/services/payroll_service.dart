import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/employee_advance.dart';
import '../models/employee_event.dart';
import '../models/payroll_record.dart';
import '../repositories/employee_repository.dart';
import 'financial_engine.dart';

/// نتيجة حساب صافي الراتب لموظف عن فترة معيّنة، مبنية على سجل حركته الوظيفي
/// (تعيين/نقل/إيقاف/عودة) وليس على رقم ثابت.
class SalaryBreakdown {
  final double baseSalary;
  final double proratedBase;
  final int daysWorked;
  final int totalDaysInPeriod;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double allowancesTotal;
  final double deductionsTotal;
  final double advancesTotal;
  final double netSalary;
  final List<int> unsettledAdvanceIds;

  const SalaryBreakdown({
    required this.baseSalary,
    required this.proratedBase,
    required this.daysWorked,
    required this.totalDaysInPeriod,
    required this.periodStart,
    required this.periodEnd,
    required this.allowancesTotal,
    required this.deductionsTotal,
    required this.advancesTotal,
    required this.netSalary,
    required this.unsettledAdvanceIds,
  });
}

class PayrollApprovalException implements Exception {
  final String message;
  PayrollApprovalException(this.message);
}

class PayrollPaymentException implements Exception {
  final String message;
  PayrollPaymentException(this.message);
}

class AdvanceFundingException implements Exception {
  final String message;
  AdvanceFundingException(this.message);
}

class LifecycleException implements Exception {
  final String message;
  LifecycleException(this.message);
}

/// فترة عمل واحدة متصلة للموظف عند فندق معيّن وبحالة نشاط معيّنة، مُستنتجة
/// من سجل حركته الوظيفي (Event Sourcing) — لا تُخزَّن، تُبنى عند كل حساب.
class _EmploymentInterval {
  final DateTime start;
  final DateTime end; // شامل (inclusive)
  final int hotelId;
  final bool isActive;
  _EmploymentInterval(this.start, this.end, this.hotelId, this.isActive);
}

/// طبقة منطق دورة حياة الموظف والرواتب: بناء الجدول الزمني من سجل الحركة،
/// حساب الراتب الجزئي حسب الأيام، اعتماد الرواتب وصرفها، النقل، الإيقاف/العودة،
/// وتمويل السلف — كل حركة مالية فعلية تمر حصراً عبر [FinancialEngine].
class PayrollService {
  final EmployeeRepository _repository;
  final FinancialEngine _financialEngine;

  PayrollService({EmployeeRepository? repository, FinancialEngine? financialEngine})
      : _repository = repository ?? EmployeeRepository(),
        _financialEngine = financialEngine ?? FinancialEngine();

  static String currentPeriod() => DateFormat('yyyy-MM').format(DateTime.now());

  static DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime _monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);

  static DateTime _parseDate(String s) => DateTime.parse(s.length > 10 ? s.substring(0, 10) : s);

  /// الفنادق التي عمل بها الموظف فعلياً خلال الشهر الحالي (بحسب سجل حركته) ولم يُعتمد
  /// راتبه فيها بعد لهذا الشهر — تظهر عادةً عند النقل منتصف الشهر بين فندقين.
  Future<List<int>> hotelsPendingApprovalThisPeriod(Employee employee) async {
    final now = DateTime.now();
    final periodStart = _monthStart(now);
    final periodEnd = _monthEnd(now);
    final events = await _repository.getEvents(employee.id!);
    final timeline = _buildTimeline(employee, events);

    final activeHotels = <int>{};
    for (final interval in timeline) {
      if (interval.isActive && _overlapDays(interval, periodStart, periodEnd) > 0) {
        activeHotels.add(interval.hotelId);
      }
    }

    final period = currentPeriod();
    final pending = <int>[];
    for (final hId in activeHotels) {
      final existing = await _repository.getPayrollRecords(hotelId: hId, employeeId: employee.id, startPeriod: period, endPeriod: period);
      if (existing.isEmpty) pending.add(hId);
    }
    return pending;
  }

  // ------------------------- الجدول الزمني لحياة الموظف الوظيفية -------------------------

  List<_EmploymentInterval> _buildTimeline(Employee employee, List<EmployeeEvent> events) {
    final sorted = [...events]..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    EmployeeEvent? hireEvent;
    for (final e in sorted) {
      if (e.eventType == EmployeeEvent.typeHire) {
        hireEvent = e;
        break;
      }
    }

    DateTime cursor;
    int currentHotel;
    if (hireEvent != null) {
      cursor = _parseDate(hireEvent.eventDate);
      currentHotel = hireEvent.hotelId;
    } else {
      // موظف قديم سابق لهذا النظام: لا يوجد حدث تعيين مسجَّل — نبدأ من بيانات ملفه الحالية.
      cursor = _parseDate(employee.hiredAt);
      currentHotel = employee.hotelId!;
    }
    bool currentActive = true;

    final intervals = <_EmploymentInterval>[];

    void closeIntervalBefore(DateTime eventDate) {
      if (eventDate.isAfter(cursor)) {
        intervals.add(_EmploymentInterval(cursor, eventDate.subtract(const Duration(days: 1)), currentHotel, currentActive));
      }
    }

    for (final event in sorted) {
      if (identical(event, hireEvent)) continue;
      final eventDate = _parseDate(event.eventDate);
      if (eventDate.isBefore(cursor)) continue; // صيانة: يتجاهل أي حدث سابق زمنياً لحالة اللقطة الحالية

      switch (event.eventType) {
        case EmployeeEvent.typeTransfer:
          closeIntervalBefore(eventDate);
          currentHotel = event.hotelId;
          cursor = eventDate;
          break;
        case EmployeeEvent.typeSuspend:
          closeIntervalBefore(eventDate);
          currentActive = false;
          cursor = eventDate;
          break;
        case EmployeeEvent.typeReturn:
          closeIntervalBefore(eventDate);
          currentActive = true;
          cursor = eventDate;
          break;
        case EmployeeEvent.typeResignation:
        case EmployeeEvent.typeTermination:
          closeIntervalBefore(eventDate);
          currentActive = false;
          cursor = eventDate;
          break;
        default:
          break; // تعديل راتب/وظيفة/ترقية/بدل/خصم لا تغيّر الجدول الزمني للحضور
      }
    }

    // الفترة المفتوحة الأخيرة تمتد حتى أفق بعيد بحالتها الحالية.
    intervals.add(_EmploymentInterval(cursor, DateTime(2100, 12, 31), currentHotel, currentActive));

    return intervals;
  }

  int _overlapDays(_EmploymentInterval interval, DateTime periodStart, DateTime periodEnd) {
    final start = interval.start.isAfter(periodStart) ? interval.start : periodStart;
    final end = interval.end.isBefore(periodEnd) ? interval.end : periodEnd;
    if (end.isBefore(start)) return 0;
    return end.difference(start).inDays + 1;
  }

  /// عدد أيام العمل الفعلية لموظف في فندق معيّن خلال فترة معيّنة، مُستنتجة تلقائياً
  /// من التعيين/النقل/الإيقاف/العودة — بدون أي إدخال يدوي.
  Future<int> calculateWorkedDays({
    required Employee employee,
    required int hotelId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final events = await _repository.getEvents(employee.id!);
    final timeline = _buildTimeline(employee, events);
    int days = 0;
    for (final interval in timeline) {
      if (interval.hotelId == hotelId && interval.isActive) {
        days += _overlapDays(interval, periodStart, periodEnd);
      }
    }
    return days;
  }

  // ------------------------- حساب الراتب -------------------------

  /// حساب الراتب لفندق معيّن (افتراضياً الفندق الحالي للموظف). يُستخدم صراحةً
  /// عند وجود نقل خلال الشهر لاحتساب حصة الفندق السابق قبل النقل أيضاً.
  Future<SalaryBreakdown> calculateBreakdown(Employee employee, {int? hotelId}) async {
    final targetHotelId = hotelId ?? employee.hotelId!;
    final now = DateTime.now();
    final periodStart = _monthStart(now);
    final periodEnd = _monthEnd(now);

    final daysWorked = await calculateWorkedDays(
      employee: employee,
      hotelId: targetHotelId,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
    final totalDays = periodEnd.difference(periodStart).inDays + 1;
    final proratedBase = daysWorked >= totalDays ? employee.salary : employee.salary * (daysWorked / totalDays);

    final allowances = await _repository.getAllowances(employee.id!);
    final deductions = await _repository.getDeductions(employee.id!);
    final advances = await _repository.getAdvances(employee.id!);
    final unsettled = advances.where((a) => !a.isSettled).toList();

    final allowancesTotal = allowances.fold(0.0, (sum, a) => sum + a.amount);
    final deductionsTotal = deductions.fold(0.0, (sum, d) => sum + d.amount);
    final advancesTotal = unsettled.fold(0.0, (sum, a) => sum + a.amount);
    final net = proratedBase + allowancesTotal - deductionsTotal - advancesTotal;

    return SalaryBreakdown(
      baseSalary: employee.salary,
      proratedBase: proratedBase,
      daysWorked: daysWorked,
      totalDaysInPeriod: totalDays,
      periodStart: periodStart,
      periodEnd: periodEnd,
      allowancesTotal: allowancesTotal,
      deductionsTotal: deductionsTotal,
      advancesTotal: advancesTotal,
      netSalary: net,
      unsettledAdvanceIds: unsettled.map((a) => a.id!).toList(),
    );
  }

  /// اعتماد الرواتب: يأخذ لقطة من راتب الشهر الحالي محسوبة حسب أيام العمل الفعلية،
  /// يقفل السلف غير المسددة عليه، ويجعله جاهزاً للصرف. بعد الاعتماد يصبح ثابتاً
  /// ولا يجوز تعديله أبداً حتى لو تغيّر راتب الموظف لاحقاً.
  Future<PayrollRecord> approveSalary(Employee employee, {int? hotelId, String? performedBy}) async {
    final targetHotelId = hotelId ?? employee.hotelId!;
    final period = currentPeriod();
    final existing = await _repository.getPayrollRecords(hotelId: targetHotelId, employeeId: employee.id, startPeriod: period, endPeriod: period);
    if (existing.isNotEmpty) {
      throw PayrollApprovalException('تم اعتماد راتب شهر $period لهذا الموظف في هذا الفندق مسبقاً، ولا يجوز اعتماده مرتين.');
    }
    // فحص وجود اعتماد سابق غير مصروف لهذا الموظف في نفس الفندق تحديداً — الاعتماد عبر
    // فنادق مختلفة (بعد النقل) مسموح أن يتم بالتوازي، كلٌّ بحصته الخاصة.
    final hotelHistory = await _repository.getPayrollRecords(hotelId: targetHotelId, employeeId: employee.id);
    final latestAtHotel = hotelHistory.isNotEmpty ? hotelHistory.first : null;
    if (latestAtHotel != null && latestAtHotel.status == PayrollRecord.statusApproved) {
      throw PayrollApprovalException('يوجد اعتماد راتب سابق لم يُصرف بعد لهذا الموظف في هذا الفندق. يجب صرفه أولاً قبل اعتماد راتب جديد.');
    }

    final breakdown = await calculateBreakdown(employee, hotelId: targetHotelId);
    final now = DateTime.now().toIso8601String();
    final df = DateFormat('yyyy-MM-dd');

    final record = PayrollRecord(
      hotelId: targetHotelId,
      employeeId: employee.id!,
      period: period,
      baseSalary: breakdown.baseSalary,
      allowancesTotal: breakdown.allowancesTotal,
      deductionsTotal: breakdown.deductionsTotal,
      advancesTotal: breakdown.advancesTotal,
      netSalary: breakdown.netSalary,
      status: PayrollRecord.statusApproved,
      approvedAt: now,
      createdAt: now,
      periodStart: df.format(breakdown.periodStart),
      periodEnd: df.format(breakdown.periodEnd),
      daysWorked: breakdown.daysWorked,
      totalDaysInPeriod: breakdown.totalDaysInPeriod,
      proratedBase: breakdown.proratedBase,
    );

    final id = await _repository.approvePayroll(record, breakdown.unsettledAdvanceIds);
    return record.copyWithId(id);
  }

  /// صرف الراتب: يوزّع صافي الراتب على مصدر واحد أو أكثر (نقد/بنك/حساب شخصي)،
  /// وينشئ حركة مالية عبر [FinancialEngine] لكل مصدر بمبلغه، ثم يقفل سجل الراتب كمصروف.
  Future<void> paySalary({
    required PayrollRecord payroll,
    required String employeeName,
    required double cashAmount,
    required double bankAmount,
    required double personalAmount,
  }) async {
    final total = cashAmount + bankAmount + personalAmount;
    if ((total - payroll.netSalary).abs() > 0.01) {
      throw PayrollPaymentException('مجموع مصادر الصرف (${total.toStringAsFixed(2)}) لا يساوي صافي الراتب (${payroll.netSalary.toStringAsFixed(2)}).');
    }

    final description = 'صرف راتب: $employeeName - ${payroll.period}';

    if (cashAmount > 0) {
      await _financialEngine.recordTransaction(
        hotelId: payroll.hotelId,
        sourceCategory: 'cash',
        amount: cashAmount,
        type: 'expense',
        description: description,
        referenceId: payroll.id,
        referenceType: 'payroll',
      );
    }
    if (bankAmount > 0) {
      await _financialEngine.recordTransaction(
        hotelId: payroll.hotelId,
        sourceCategory: 'bank',
        amount: bankAmount,
        type: 'expense',
        description: description,
        referenceId: payroll.id,
        referenceType: 'payroll',
      );
    }
    if (personalAmount > 0) {
      // صرف من حساب شخصي: يسجَّل التزاماً (ديناً) على المنشأة لصالح صاحب الحساب.
      await _financialEngine.recordTransaction(
        hotelId: payroll.hotelId,
        sourceCategory: 'personal',
        amount: personalAmount,
        type: 'expense',
        description: description,
        referenceId: payroll.id,
        referenceType: 'payroll',
      );
    }

    final sourcesUsed = [
      if (cashAmount > 0) 'نقد',
      if (bankAmount > 0) 'بنك',
      if (personalAmount > 0) 'شخصي',
    ];
    final sourceLabel = sourcesUsed.length > 1 ? 'موزع' : sourcesUsed.first;

    await _repository.markPayrollPaid(payroll.id!, {
      'status': PayrollRecord.statusPaid,
      'payment_source': sourceLabel,
      'cash_amount': cashAmount,
      'bank_amount': bankAmount,
      'personal_amount': personalAmount,
      'paid_at': DateTime.now().toIso8601String(),
    });
  }

  // ------------------------- دورة حياة الموظف -------------------------

  Future<void> hireEmployee(Employee employee, {String? performedBy}) async {
    final now = DateTime.now().toIso8601String();
    await _repository.addEvent(EmployeeEvent(
      employeeId: employee.id!,
      hotelId: employee.hotelId!,
      eventType: EmployeeEvent.typeHire,
      eventDate: employee.hiredAt,
      reason: 'تعيين الموظف',
      performedBy: performedBy,
      newValue: employee.position,
      createdAt: now,
    ));
  }

  /// نقل الموظف إلى فندق آخر: نفس السجل ونفس الرقم الوظيفي ينتقلان، وتُغلَق فترة
  /// عمله في الفندق الحالي وتُفتح فترة جديدة في الفندق الجديد تلقائياً.
  Future<void> transferEmployee({
    required Employee employee,
    required int newHotelId,
    required String oldHotelName,
    required String newHotelName,
    required String transferDate,
    required String reason,
    String? performedBy,
    String? notes,
  }) async {
    if (newHotelId == employee.hotelId) {
      throw LifecycleException('لا يمكن نقل الموظف إلى نفس الفندق الحالي.');
    }
    final now = DateTime.now().toIso8601String();
    final event = EmployeeEvent(
      employeeId: employee.id!,
      hotelId: newHotelId,
      eventType: EmployeeEvent.typeTransfer,
      eventDate: transferDate,
      reason: reason,
      performedBy: performedBy,
      notes: notes,
      oldValue: oldHotelName,
      newValue: newHotelName,
      createdAt: now,
    );
    await _repository.transferEmployee(employee.id!, newHotelId, event);
  }

  Future<void> suspendEmployee({
    required Employee employee,
    required String suspendDate,
    required String reason,
    String? performedBy,
    String? notes,
  }) async {
    if (employee.status == Employee.statusSuspended) {
      throw LifecycleException('الموظف موقوف بالفعل.');
    }
    final now = DateTime.now().toIso8601String();
    final event = EmployeeEvent(
      employeeId: employee.id!,
      hotelId: employee.hotelId!,
      eventType: EmployeeEvent.typeSuspend,
      eventDate: suspendDate,
      reason: reason,
      performedBy: performedBy,
      notes: notes,
      createdAt: now,
    );
    await _repository.changeStatus(employee.id!, Employee.statusSuspended, event);
  }

  Future<void> returnToWork({
    required Employee employee,
    required String returnDate,
    String? performedBy,
    String? notes,
  }) async {
    if (employee.status != Employee.statusSuspended) {
      throw LifecycleException('الموظف ليس في حالة إيقاف.');
    }
    final now = DateTime.now().toIso8601String();
    final event = EmployeeEvent(
      employeeId: employee.id!,
      hotelId: employee.hotelId!,
      eventType: EmployeeEvent.typeReturn,
      eventDate: returnDate,
      reason: 'عودة للعمل',
      performedBy: performedBy,
      notes: notes,
      createdAt: now,
    );
    await _repository.changeStatus(employee.id!, Employee.statusActive, event);
  }

  Future<void> resignEmployee({
    required Employee employee,
    required String date,
    required String reason,
    String? performedBy,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final event = EmployeeEvent(
      employeeId: employee.id!,
      hotelId: employee.hotelId!,
      eventType: EmployeeEvent.typeResignation,
      eventDate: date,
      reason: reason,
      performedBy: performedBy,
      notes: notes,
      createdAt: now,
    );
    await _repository.changeStatus(employee.id!, Employee.statusResigned, event);
  }

  Future<void> terminateEmployee({
    required Employee employee,
    required String date,
    required String reason,
    String? performedBy,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final event = EmployeeEvent(
      employeeId: employee.id!,
      hotelId: employee.hotelId!,
      eventType: EmployeeEvent.typeTermination,
      eventDate: date,
      reason: reason,
      performedBy: performedBy,
      notes: notes,
      createdAt: now,
    );
    await _repository.changeStatus(employee.id!, Employee.statusTerminated, event);
  }

  Future<void> changeSalary({
    required Employee employee,
    required double newSalary,
    required String reason,
    String? performedBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    final event = EmployeeEvent(
      employeeId: employee.id!,
      hotelId: employee.hotelId!,
      eventType: EmployeeEvent.typeSalaryChange,
      eventDate: now.substring(0, 10),
      reason: reason,
      performedBy: performedBy,
      oldValue: employee.salary.toStringAsFixed(2),
      newValue: newSalary.toStringAsFixed(2),
      createdAt: now,
    );
    await _repository.applyFieldChange(employee.id!, {'salary': newSalary}, event);
  }

  Future<void> changePosition({
    required Employee employee,
    required String newPosition,
    required String reason,
    String? performedBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    final event = EmployeeEvent(
      employeeId: employee.id!,
      hotelId: employee.hotelId!,
      eventType: EmployeeEvent.typePositionChange,
      eventDate: now.substring(0, 10),
      reason: reason,
      performedBy: performedBy,
      oldValue: employee.position,
      newValue: newPosition,
      createdAt: now,
    );
    await _repository.applyFieldChange(employee.id!, {'position': newPosition}, event);
  }

  Future<void> promoteEmployee({
    required Employee employee,
    required String newPosition,
    double? newSalary,
    required String reason,
    String? performedBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    final fieldUpdate = <String, dynamic>{'position': newPosition};
    if (newSalary != null) fieldUpdate['salary'] = newSalary;
    final event = EmployeeEvent(
      employeeId: employee.id!,
      hotelId: employee.hotelId!,
      eventType: EmployeeEvent.typePromotion,
      eventDate: now.substring(0, 10),
      reason: reason,
      performedBy: performedBy,
      oldValue: '${employee.position} — ${employee.salary.toStringAsFixed(2)}',
      newValue: '$newPosition — ${(newSalary ?? employee.salary).toStringAsFixed(2)}',
      createdAt: now,
    );
    await _repository.applyFieldChange(employee.id!, fieldUpdate, event);
  }

  Future<void> archiveEmployee({
    required Employee employee,
    required String reason,
    String? performedBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    final event = EmployeeEvent(
      employeeId: employee.id!,
      hotelId: employee.hotelId!,
      eventType: EmployeeEvent.typeArchived,
      eventDate: now.substring(0, 10),
      reason: reason,
      performedBy: performedBy,
      createdAt: now,
    );
    await _repository.archiveEmployee(employee.id!, event);
  }

  // ------------------------- السلف (عملية مالية كاملة) -------------------------

  /// إضافة سلفة: تُنشئ الحركة المالية الفعلية فوراً عبر [FinancialEngine] حسب مصادر
  /// التمويل المختارة (يمكن توزيعها على أكثر من مصدر)، ثم تُخصم لاحقاً من الراتب
  /// تلقائياً عند اعتماد الرواتب القادم.
  Future<EmployeeAdvance> addAdvance({
    required Employee employee,
    required double amount,
    required String date,
    String? notes,
    required double cash,
    required double bank,
    required double personal,
    required double entity,
    int? entityHotelId,
  }) async {
    final total = cash + bank + personal + entity;
    if ((total - amount).abs() > 0.01) {
      throw AdvanceFundingException('مجموع مصادر التمويل (${total.toStringAsFixed(2)}) لا يساوي مبلغ السلفة (${amount.toStringAsFixed(2)}).');
    }
    if (entity > 0 && entityHotelId == null) {
      throw AdvanceFundingException('يجب تحديد المنشأة الممولة عند اختيار مصدر "منشأة أخرى".');
    }

    final description = 'سلفة موظف: ${employee.name} (${employee.employeeNumber ?? ''})';

    if (cash > 0) {
      await _financialEngine.recordTransaction(
        hotelId: employee.hotelId!, sourceCategory: 'cash', amount: cash,
        type: 'expense', description: description, referenceType: 'employee_advance',
      );
    }
    if (bank > 0) {
      await _financialEngine.recordTransaction(
        hotelId: employee.hotelId!, sourceCategory: 'bank', amount: bank,
        type: 'expense', description: description, referenceType: 'employee_advance',
      );
    }
    if (personal > 0) {
      await _financialEngine.recordTransaction(
        hotelId: employee.hotelId!, sourceCategory: 'personal', amount: personal,
        type: 'expense', description: description, referenceType: 'employee_advance',
      );
    }
    if (entity > 0) {
      await _financialEngine.recordTransaction(
        hotelId: employee.hotelId!, sourceCategory: 'entity_$entityHotelId', amount: entity,
        type: 'expense', description: description, referenceType: 'employee_advance',
        otherHotelId: entityHotelId,
      );
    }

    final advance = EmployeeAdvance(
      hotelId: employee.hotelId!,
      employeeId: employee.id!,
      amount: amount,
      date: date,
      notes: notes,
      createdAt: DateTime.now().toIso8601String(),
      cashAmount: cash,
      bankAmount: bank,
      personalAmount: personal,
      entityAmount: entity,
      entityHotelId: entityHotelId,
    );
    final id = await _repository.addAdvance(advance);
    return EmployeeAdvance(
      id: id, hotelId: advance.hotelId, employeeId: advance.employeeId, amount: advance.amount,
      date: advance.date, notes: advance.notes, createdAt: advance.createdAt,
      cashAmount: advance.cashAmount, bankAmount: advance.bankAmount, personalAmount: advance.personalAmount,
      entityAmount: advance.entityAmount, entityHotelId: advance.entityHotelId,
    );
  }
}

extension on PayrollRecord {
  PayrollRecord copyWithId(int newId) {
    return PayrollRecord(
      id: newId,
      hotelId: hotelId,
      employeeId: employeeId,
      period: period,
      baseSalary: baseSalary,
      allowancesTotal: allowancesTotal,
      deductionsTotal: deductionsTotal,
      advancesTotal: advancesTotal,
      netSalary: netSalary,
      status: status,
      paymentSource: paymentSource,
      cashAmount: cashAmount,
      bankAmount: bankAmount,
      personalAmount: personalAmount,
      approvedAt: approvedAt,
      paidAt: paidAt,
      createdAt: createdAt,
      periodStart: periodStart,
      periodEnd: periodEnd,
      daysWorked: daysWorked,
      totalDaysInPeriod: totalDaysInPeriod,
      proratedBase: proratedBase,
    );
  }
}
