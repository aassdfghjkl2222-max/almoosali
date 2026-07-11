import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/financial_report.dart';
import '../models/hotel.dart';
import '../models/invoice.dart';
import '../models/supplier.dart';

class ExcelService {
  static Future<void> exportFinancialReport({
    required Hotel hotel,
    required List<FinancialReport> reports,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final excel = createExcelReport(
      hotel: hotel,
      reports: reports,
      fromDate: fromDate,
      toDate: toDate,
    );

    // Save file
    final bytes = excel.save();
    if (bytes != null) {
      final directory = await getTemporaryDirectory();
      final fileName = "التقرير_المالي_${hotel.arabicName}_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final file = File("${directory.path}/$fileName");
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles([XFile(file.path)], text: "التقرير المالي - ${hotel.arabicName}");
    }
  }

  static Excel createExcelReport({
    required Hotel hotel,
    required List<FinancialReport> reports,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'التقرير المالي');
    
    final mainSheet = excel['التقرير المالي'];

    // 1. Header
    mainSheet.cell(CellIndex.indexByString("A1")).value = TextCellValue("التقرير المالي");
    mainSheet.cell(CellIndex.indexByString("A2")).value = TextCellValue("الفترة:");
    mainSheet.cell(CellIndex.indexByString("B2")).value = TextCellValue("من: ${fromDate.day}/${fromDate.month}/${fromDate.year}");
    mainSheet.cell(CellIndex.indexByString("C2")).value = TextCellValue("إلى: ${toDate.day}/${toDate.month}/${toDate.year}");
    mainSheet.cell(CellIndex.indexByString("A3")).value = TextCellValue("الفندق:");
    mainSheet.cell(CellIndex.indexByString("B3")).value = TextCellValue(hotel.arabicName);

    // 2. Identify dynamic expense columns
    Set<String> dynamicExpenseTypes = {};
    for (var report in reports) {
      if (report.detailsJson != null) {
        try {
          final details = jsonDecode(report.detailsJson!);
          final expense = details['expense_details'] ?? {};
          final others = expense['other'] as List? ?? [];
          for (var item in others) {
            if (item['type'] != null && item['type'].toString().isNotEmpty) {
              dynamicExpenseTypes.add(item['type'].toString());
            }
          }
        } catch (_) {}
      }
    }
    List<String> sortedExpenseTypes = dynamicExpenseTypes.toList()..sort();

    // 3. Define Table Headers
    List<String> headers = [
      "التاريخ",
      "اليوم",
      "النقد",
      "الشبكة",
      "التحويل البنكي",
      "مواقف (نقد)",
      "مواقف (شبكة)",
      "إجمالي الإيرادات",
      "إعاشة (نقد)",
      "إعاشة (شبكة)",
      "استرداد (نقد)",
      "استرداد (شبكة)",
      "تحويل من النقد إلى الشبكة",
    ];

    // Add dynamic expense columns
    for (var type in sortedExpenseTypes) {
      headers.add("$type (نقد)");
      headers.add("$type (شبكة)");
    }

    headers.addAll([
      "الزيادة (نقد)",
      "الزيادة (شبكة)",
      "النقص (نقد)",
      "النقص (شبكة)",
      "صافي النقد",
      "صافي الشبكة",
      "الرصيد النهائي",
    ]);

    // Write headers to row 5 (index 4)
    for (int i = 0; i < headers.length; i++) {
      var cell = mainSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString("#FFFFFF"),
        backgroundColorHex: ExcelColor.fromHexString("#2E7D32"), // Dark Green
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );
    }

    // 4. Data Rows
    int currentRow = 5;
    Map<int, double> columnTotals = {};

    for (var report in reports.reversed) { // Original order (oldest to newest)
      final date = DateTime.parse(report.date);
      final dayName = _getDayName(date.weekday);
      
      Map<String, dynamic> details = {};
      if (report.detailsJson != null) {
        try {
          details = jsonDecode(report.detailsJson!);
        } catch (_) {}
      }

      final income = details['income_details'] ?? {};
      final expense = details['expense_details'] ?? {};
      final adjust = details['adjustments'] ?? {};

      double cash = _toDouble(income['cash']);
      double pos = _toDouble(income['pos']);
      double pCash = _toDouble(income['parking_cash']);
      double pPos = _toDouble(income['parking_pos']);
      double trans = _toDouble(income['transfer']);
      double totalInc = cash + pos + pCash + pPos + trans;

      double sub = _toDouble(expense['subsistence']);
      String subM = expense['subsistence_method'] ?? "نقد";
      double subCash = subM == "نقد" ? sub : 0;
      double subPos = subM == "شبكة" ? sub : 0;

      double ref = _toDouble(expense['refund']);
      String refM = expense['refund_method'] ?? "نقد";
      double refCash = refM == "نقد" ? ref : 0;
      double refPos = refM == "شبكة" ? ref : 0;

      double c2p = _toDouble(expense['cash_to_pos']);

      // Dynamic expenses
      Map<String, double> otherCashMap = {};
      Map<String, double> otherPosMap = {};
      final others = expense['other'] as List? ?? [];
      double totalOtherCash = 0;
      double totalOtherPos = 0;
      
      for (var item in others) {
        double amt = _toDouble(item['amount']);
        String type = item['type']?.toString() ?? "أخرى";
        if (item['method'] == "نقد") {
          otherCashMap[type] = (otherCashMap[type] ?? 0) + amt;
          totalOtherCash += amt;
        } else {
          otherPosMap[type] = (otherPosMap[type] ?? 0) + amt;
          totalOtherPos += amt;
        }
      }

      double inc = _toDouble(adjust['increase']);
      double sho = _toDouble(adjust['shortage']);
      String incEff = adjust['increase_effect'] ?? "نقد";
      String shoEff = adjust['shortage_effect'] ?? "نقد";
      
      double incCash = incEff == "نقد" ? inc : 0;
      double incPos = incEff == "شبكة" ? inc : 0;
      double shoCash = shoEff == "نقد" ? sho : 0;
      double shoPos = shoEff == "شبكة" ? sho : 0;

      double netCash = (cash + pCash + incCash) - (subCash + refCash + c2p + totalOtherCash + shoCash);
      double netPos = (pos + pPos + incPos + c2p) - (subPos + refPos + totalOtherPos + shoPos);
      double finalBal = netCash + netPos + trans;

      List<dynamic> rowData = [
        "${date.day}/${date.month}/${date.year}",
        dayName,
        cash,
        pos,
        trans,
        pCash,
        pPos,
        totalInc,
        subCash,
        subPos,
        refCash,
        refPos,
        c2p,
      ];

      // Add dynamic expense values
      for (var type in sortedExpenseTypes) {
        rowData.add(otherCashMap[type] ?? 0);
        rowData.add(otherPosMap[type] ?? 0);
      }

      rowData.addAll([
        incCash,
        incPos,
        shoCash,
        shoPos,
        netCash,
        netPos,
        finalBal,
      ]);

      for (int i = 0; i < rowData.length; i++) {
        var cell = mainSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        var val = rowData[i];
        if (val is double) {
          cell.value = DoubleCellValue(val);
          columnTotals[i] = (columnTotals[i] ?? 0) + val;
        } else {
          cell.value = TextCellValue(val.toString());
        }
        
        cell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );
      }
      currentRow++;
    }

    // 5. Totals Section
    currentRow++;
    mainSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue("الإجماليات");
    mainSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = CellStyle(bold: true);

    for (int i = 2; i < headers.length; i++) {
      var cell = mainSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
      cell.value = DoubleCellValue(columnTotals[i] ?? 0);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString("#F0F0F0"),
        horizontalAlign: HorizontalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );
    }

    // Final formatting
    for (int i = 0; i < headers.length; i++) {
       mainSheet.setColumnWidth(i, 15);
    }
    
    return excel;
  }

  static Future<void> exportSupplierInvoices({
    required String companyName,
    required List<Invoice> invoices,
    Supplier? supplier,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'تقرير فواتير المورد');
    final sheet = excel['تقرير فواتير المورد'];

    // Header
    sheet.cell(CellIndex.indexByString("A1")).value = TextCellValue("تقرير فواتير المورد");
    sheet.cell(CellIndex.indexByString("A2")).value = TextCellValue("المورد:");
    sheet.cell(CellIndex.indexByString("B2")).value = TextCellValue(companyName);
    
    if (supplier != null) {
      sheet.cell(CellIndex.indexByString("A3")).value = TextCellValue("الرقم الضريبي:");
      sheet.cell(CellIndex.indexByString("B3")).value = TextCellValue(supplier.taxNumber);
    }

    if (fromDate != null && toDate != null) {
      sheet.cell(CellIndex.indexByString("A4")).value = TextCellValue("الفترة:");
      sheet.cell(CellIndex.indexByString("B4")).value = TextCellValue("من: ${fromDate.day}/${fromDate.month}/${fromDate.year}");
      sheet.cell(CellIndex.indexByString("C4")).value = TextCellValue("إلى: ${toDate.day}/${toDate.month}/${toDate.year}");
    }

    // Table Headers
    List<String> headers = [
      "رقم الفاتورة",
      "التاريخ",
      "اسم الشركة",
      "الرقم الضريبي",
      "المبلغ قبل الضريبة",
      "ضريبة القيمة المضافة",
      "المبلغ الإجمالي",
      "المنشأة",
    ];

    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 5));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString("#2E7D32"),
        fontColorHex: ExcelColor.fromHexString("#FFFFFF"),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Data
    for (int i = 0; i < invoices.length; i++) {
      final inv = invoices[i];
      int rowIndex = 6 + i;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(inv.invoiceNumber);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(inv.date);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(inv.companyName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(inv.taxNumber);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(inv.amountBeforeTax);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(inv.vat);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(inv.totalAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = TextCellValue(inv.facilityName);
      
      // Formatting
      for (int j = 0; j < headers.length; j++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex)).cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );
      }
    }

    // Column widths
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }

    // Save and share
    final bytes = excel.save();
    if (bytes != null) {
      final directory = await getTemporaryDirectory();
      final fileName = "تقرير_فواتير_${companyName}_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final file = File("${directory.path}/$fileName");
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles([XFile(file.path)], text: "تقرير فواتير المورد - $companyName");
    }
  }

  static Future<void> exportGeneralInvoicesReport({
    required String hotelName,
    required List<Invoice> invoices,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'تقرير الفواتير الإلكترونية');
    final sheet = excel['تقرير الفواتير الإلكترونية'];

    // Header
    sheet.cell(CellIndex.indexByString("A1")).value = TextCellValue("تقرير الفواتير الإلكترونية");
    sheet.cell(CellIndex.indexByString("A2")).value = TextCellValue("الفندق / المنشأة:");
    sheet.cell(CellIndex.indexByString("B2")).value = TextCellValue(hotelName);

    if (fromDate != null || toDate != null) {
      sheet.cell(CellIndex.indexByString("A3")).value = TextCellValue("الفترة:");
      String period = "";
      if (fromDate != null) period += "من: ${fromDate.day}/${fromDate.month}/${fromDate.year} ";
      if (toDate != null) period += "إلى: ${toDate.day}/${toDate.month}/${toDate.year}";
      sheet.cell(CellIndex.indexByString("B3")).value = TextCellValue(period);
    }

    // Table Headers
    List<String> headers = [
      "رقم الفاتورة",
      "اسم الشركة",
      "الرقم الضريبي",
      "المبلغ قبل الضريبة",
      "قيمة الضريبة",
      "إجمالي الفاتورة",
      "الفندق",
    ];

    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 5));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString("#2E7D32"),
        fontColorHex: ExcelColor.fromHexString("#FFFFFF"),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Data
    double totalBeforeTax = 0;
    double totalVat = 0;
    double totalAmount = 0;

    for (int i = 0; i < invoices.length; i++) {
      final inv = invoices[i];
      int rowIndex = 6 + i;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(inv.invoiceNumber);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(inv.companyName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(inv.taxNumber);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(inv.amountBeforeTax);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(inv.vat);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(inv.totalAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(inv.facilityName);
      
      totalBeforeTax += inv.amountBeforeTax;
      totalVat += inv.vat;
      totalAmount += inv.totalAmount;

      // Formatting
      for (int j = 0; j < headers.length; j++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex)).cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );
      }
    }

    // Totals Row
    int totalsRow = 6 + invoices.length;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: totalsRow)).value = TextCellValue("الإجماليات:");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalsRow)).value = DoubleCellValue(totalBeforeTax);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalsRow)).value = DoubleCellValue(totalVat);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalsRow)).value = DoubleCellValue(totalAmount);

    for (int j = 2; j <= 5; j++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: totalsRow)).cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString("#F5F5F5"),
        horizontalAlign: HorizontalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );
    }

    // Column widths
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }

    // Save and share
    final bytes = excel.save();
    if (bytes != null) {
      final directory = await getTemporaryDirectory();
      final fileName = "تقرير_الفواتير_${hotelName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final file = File("${directory.path}/$fileName");
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles([XFile(file.path)], text: "تقرير الفواتير الإلكترونية - $hotelName");
    }
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0;
    return double.tryParse(val.toString()) ?? 0;
  }

  static String _getDayName(int day) {
    switch (day) {
      case DateTime.sunday: return "الأحد";
      case DateTime.monday: return "الاثنين";
      case DateTime.tuesday: return "الثلاثاء";
      case DateTime.wednesday: return "الأربعاء";
      case DateTime.thursday: return "الخميس";
      case DateTime.friday: return "الجمعة";
      case DateTime.saturday: return "السبت";
      default: return "";
    }
  }

  /// تصدير تقرير الرواتب. كل عنصر في [rows] بالمفاتيح:
  /// name, position, base, allowances, deductions, net, cash, bank, personal.
  /// لا تُعرض تفاصيل السلف داخل هذا الكشف عمداً.
  static Future<void> exportPayrollReport({
    required Hotel hotel,
    required String period,
    required List<Map<String, dynamic>> rows,
  }) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'تقرير الرواتب');
    final sheet = excel['تقرير الرواتب'];

    sheet.cell(CellIndex.indexByString("A1")).value = TextCellValue("تقرير الرواتب");
    sheet.cell(CellIndex.indexByString("A2")).value = TextCellValue("المنشأة:");
    sheet.cell(CellIndex.indexByString("B2")).value = TextCellValue(hotel.arabicName);
    sheet.cell(CellIndex.indexByString("A3")).value = TextCellValue("الفترة:");
    sheet.cell(CellIndex.indexByString("B3")).value = TextCellValue(period);

    final headers = [
      "اسم الموظف",
      "الوظيفة",
      "الراتب الأساسي",
      "البدلات",
      "الخصومات",
      "صافي الراتب",
      "المدفوع نقداً",
      "المدفوع بنكياً",
      "المدفوع من الحساب الشخصي",
    ];

    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 5));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString("#2E7D32"),
        fontColorHex: ExcelColor.fromHexString("#FFFFFF"),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rowIndex = 6 + i;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(r['name']?.toString() ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(r['position']?.toString() ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = DoubleCellValue(_toDouble(r['base']));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(_toDouble(r['allowances']));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(_toDouble(r['deductions']));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(_toDouble(r['net']));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(_toDouble(r['cash']));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = DoubleCellValue(_toDouble(r['bank']));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = DoubleCellValue(_toDouble(r['personal']));

      for (int j = 0; j < headers.length; j++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex)).cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );
      }
    }

    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }

    final bytes = excel.save();
    if (bytes != null) {
      final directory = await getTemporaryDirectory();
      final fileName = "تقرير_الرواتب_${hotel.arabicName}_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final file = File("${directory.path}/$fileName");
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], text: "تقرير الرواتب - ${hotel.arabicName} - $period");
    }
  }
}
