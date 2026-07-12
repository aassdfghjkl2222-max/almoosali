import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _db;
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'manazel.db');
    return await openDatabase(
      path,
      version: 24, // Upgrade to v24 for event-sourced Employee Lifecycle module
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createTables(db);
        await _initializeData(db);
      },
      // شبكة أمان: تُعاد بعد كل فتح لقاعدة البيانات (وليس فقط أثناء الترقية لمرة واحدة)،
      // للتعافي تلقائياً إن فشل أحد أوامر ALTER TABLE سابقاً لأي سبب عابر ولم يُكتشف.
      onOpen: (db) async => await _ensureSchemaHealth(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 21) {
          try { await db.execute('ALTER TABLE financial_reports ADD COLUMN is_posted INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
          // ... (existing v21 migration logic)
        }
        if (oldVersion < 22) {
          try { await db.execute('ALTER TABLE financial_reports ADD COLUMN report_type TEXT NOT NULL DEFAULT "main"'); } catch (_) {}
          try { await db.execute('ALTER TABLE financial_reports ADD COLUMN is_locked INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
        }
        if (oldVersion < 23) {
          try { await db.execute('ALTER TABLE employees ADD COLUMN phone TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE employees ADD COLUMN status TEXT NOT NULL DEFAULT "active"'); } catch (_) {}
          try { await db.execute('ALTER TABLE employees ADD COLUMN notes TEXT'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS payroll_records (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, period TEXT NOT NULL, base_salary REAL NOT NULL, allowances_total REAL NOT NULL DEFAULT 0, deductions_total REAL NOT NULL DEFAULT 0, advances_total REAL NOT NULL DEFAULT 0, net_salary REAL NOT NULL, status TEXT NOT NULL DEFAULT "approved", payment_source TEXT, cash_amount REAL NOT NULL DEFAULT 0, bank_amount REAL NOT NULL DEFAULT 0, personal_amount REAL NOT NULL DEFAULT 0, approved_at TEXT NOT NULL, paid_at TEXT, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS employee_allowances (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, name TEXT NOT NULL, amount REAL NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS employee_deductions (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, name TEXT NOT NULL, amount REAL NOT NULL, notes TEXT, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS employee_advances (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL, notes TEXT, is_settled INTEGER NOT NULL DEFAULT 0, payroll_id INTEGER, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE, FOREIGN KEY (payroll_id) REFERENCES payroll_records (id) ON DELETE SET NULL)'); } catch (_) {}
        }
        if (oldVersion < 24) {
          try { await db.execute('ALTER TABLE employees ADD COLUMN employee_number TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE employees ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
          try {
            final rows = await db.query('employees', where: 'employee_number IS NULL');
            for (var row in rows) {
              await db.update('employees', {'employee_number': 'EMP-${(row['id'] as int).toString().padLeft(6, '0')}'}, where: 'id = ?', whereArgs: [row['id']]);
            }
          } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS employee_events (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, event_type TEXT NOT NULL, event_date TEXT NOT NULL, reason TEXT, performed_by TEXT, notes TEXT, old_value TEXT, new_value TEXT, created_at TEXT NOT NULL, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS employee_documents (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER NOT NULL, type TEXT NOT NULL, name TEXT NOT NULL, expiry_date TEXT, notes TEXT, created_at TEXT NOT NULL, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)'); } catch (_) {}
          try { await db.execute('ALTER TABLE employee_advances ADD COLUMN cash_amount REAL NOT NULL DEFAULT 0'); } catch (_) {}
          try { await db.execute('ALTER TABLE employee_advances ADD COLUMN bank_amount REAL NOT NULL DEFAULT 0'); } catch (_) {}
          try { await db.execute('ALTER TABLE employee_advances ADD COLUMN personal_amount REAL NOT NULL DEFAULT 0'); } catch (_) {}
          try { await db.execute('ALTER TABLE employee_advances ADD COLUMN entity_amount REAL NOT NULL DEFAULT 0'); } catch (_) {}
          try { await db.execute('ALTER TABLE employee_advances ADD COLUMN entity_hotel_id INTEGER'); } catch (_) {}
          try { await db.execute('ALTER TABLE payroll_records ADD COLUMN period_start TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE payroll_records ADD COLUMN period_end TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE payroll_records ADD COLUMN days_worked INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
          try { await db.execute('ALTER TABLE payroll_records ADD COLUMN total_days_in_period INTEGER NOT NULL DEFAULT 30'); } catch (_) {}
          try { await db.execute('ALTER TABLE payroll_records ADD COLUMN prorated_base REAL NOT NULL DEFAULT 0'); } catch (_) {}
        }
      },
    );
  }

  /// يتحقق من وجود الأعمدة/الجداول الحرجة التي تُضاف عادة عبر ALTER TABLE في onUpgrade،
  /// ويضيف الناقص منها بصمت. يعمل عند كل فتح لقاعدة البيانات — وليس فقط أثناء ترقية
  /// رقم الإصدار — حتى لا يترك أي فشل عابر وغير مكتشف لأمر ALTER التطبيق في حالة معطوبة دائماً.
  Future<void> _ensureSchemaHealth(Database db) async {
    Future<bool> hasColumn(String table, String column) async {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.any((c) => c['name'] == column);
    }

    try {
      if (!await hasColumn('employees', 'employee_number')) {
        await db.execute('ALTER TABLE employees ADD COLUMN employee_number TEXT');
      }
      if (!await hasColumn('employees', 'is_archived')) {
        await db.execute('ALTER TABLE employees ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0');
      }
      if (!await hasColumn('employees', 'phone')) {
        await db.execute('ALTER TABLE employees ADD COLUMN phone TEXT');
      }
      if (!await hasColumn('employees', 'status')) {
        await db.execute('ALTER TABLE employees ADD COLUMN status TEXT NOT NULL DEFAULT "active"');
      }
      if (!await hasColumn('employees', 'notes')) {
        await db.execute('ALTER TABLE employees ADD COLUMN notes TEXT');
      }
      final missingNumbers = await db.query('employees', where: 'employee_number IS NULL');
      for (var row in missingNumbers) {
        await db.update('employees', {'employee_number': 'EMP-${(row['id'] as int).toString().padLeft(6, '0')}'}, where: 'id = ?', whereArgs: [row['id']]);
      }

      await db.execute('CREATE TABLE IF NOT EXISTS payroll_records (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, period TEXT NOT NULL, base_salary REAL NOT NULL, allowances_total REAL NOT NULL DEFAULT 0, deductions_total REAL NOT NULL DEFAULT 0, advances_total REAL NOT NULL DEFAULT 0, net_salary REAL NOT NULL, status TEXT NOT NULL DEFAULT "approved", payment_source TEXT, cash_amount REAL NOT NULL DEFAULT 0, bank_amount REAL NOT NULL DEFAULT 0, personal_amount REAL NOT NULL DEFAULT 0, approved_at TEXT NOT NULL, paid_at TEXT, created_at TEXT NOT NULL, period_start TEXT, period_end TEXT, days_worked INTEGER NOT NULL DEFAULT 0, total_days_in_period INTEGER NOT NULL DEFAULT 30, prorated_base REAL NOT NULL DEFAULT 0, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)');
      await db.execute('CREATE TABLE IF NOT EXISTS employee_allowances (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, name TEXT NOT NULL, amount REAL NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)');
      await db.execute('CREATE TABLE IF NOT EXISTS employee_deductions (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, name TEXT NOT NULL, amount REAL NOT NULL, notes TEXT, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)');
      await db.execute('CREATE TABLE IF NOT EXISTS employee_advances (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL, notes TEXT, is_settled INTEGER NOT NULL DEFAULT 0, payroll_id INTEGER, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE, FOREIGN KEY (payroll_id) REFERENCES payroll_records (id) ON DELETE SET NULL)');
      await db.execute('CREATE TABLE IF NOT EXISTS employee_events (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, event_type TEXT NOT NULL, event_date TEXT NOT NULL, reason TEXT, performed_by TEXT, notes TEXT, old_value TEXT, new_value TEXT, created_at TEXT NOT NULL, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
      await db.execute('CREATE TABLE IF NOT EXISTS employee_documents (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER NOT NULL, type TEXT NOT NULL, name TEXT NOT NULL, expiry_date TEXT, notes TEXT, created_at TEXT NOT NULL, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)');

      if (!await hasColumn('employee_advances', 'cash_amount')) {
        await db.execute('ALTER TABLE employee_advances ADD COLUMN cash_amount REAL NOT NULL DEFAULT 0');
      }
      if (!await hasColumn('employee_advances', 'bank_amount')) {
        await db.execute('ALTER TABLE employee_advances ADD COLUMN bank_amount REAL NOT NULL DEFAULT 0');
      }
      if (!await hasColumn('employee_advances', 'personal_amount')) {
        await db.execute('ALTER TABLE employee_advances ADD COLUMN personal_amount REAL NOT NULL DEFAULT 0');
      }
      if (!await hasColumn('employee_advances', 'entity_amount')) {
        await db.execute('ALTER TABLE employee_advances ADD COLUMN entity_amount REAL NOT NULL DEFAULT 0');
      }
      if (!await hasColumn('employee_advances', 'entity_hotel_id')) {
        await db.execute('ALTER TABLE employee_advances ADD COLUMN entity_hotel_id INTEGER');
      }
      if (!await hasColumn('payroll_records', 'period_start')) {
        await db.execute('ALTER TABLE payroll_records ADD COLUMN period_start TEXT');
      }
      if (!await hasColumn('payroll_records', 'period_end')) {
        await db.execute('ALTER TABLE payroll_records ADD COLUMN period_end TEXT');
      }
      if (!await hasColumn('payroll_records', 'days_worked')) {
        await db.execute('ALTER TABLE payroll_records ADD COLUMN days_worked INTEGER NOT NULL DEFAULT 0');
      }
      if (!await hasColumn('payroll_records', 'total_days_in_period')) {
        await db.execute('ALTER TABLE payroll_records ADD COLUMN total_days_in_period INTEGER NOT NULL DEFAULT 30');
      }
      if (!await hasColumn('payroll_records', 'prorated_base')) {
        await db.execute('ALTER TABLE payroll_records ADD COLUMN prorated_base REAL NOT NULL DEFAULT 0');
      }
    } catch (_) {
      // لا نمنع فتح قاعدة البيانات إن تعذّر أحد فحوصات الصيانة — التطبيق يبقى قابلاً للعمل
      // بالحد الأدنى، وتُعاد المحاولة تلقائياً عند فتح التطبيق مرة أخرى.
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS hotels (id INTEGER PRIMARY KEY AUTOINCREMENT, arabic_name TEXT NOT NULL, english_name TEXT NOT NULL, city TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1, has_parking INTEGER NOT NULL DEFAULT 0, identity_color_value INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, name TEXT NOT NULL, expiry_date TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, title TEXT NOT NULL, content TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS employees (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, name TEXT NOT NULL, position TEXT NOT NULL, salary REAL NOT NULL, hired_at TEXT NOT NULL, phone TEXT, status TEXT NOT NULL DEFAULT "active", notes TEXT, employee_number TEXT, is_archived INTEGER NOT NULL DEFAULT 0, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS payroll_records (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, period TEXT NOT NULL, base_salary REAL NOT NULL, allowances_total REAL NOT NULL DEFAULT 0, deductions_total REAL NOT NULL DEFAULT 0, advances_total REAL NOT NULL DEFAULT 0, net_salary REAL NOT NULL, status TEXT NOT NULL DEFAULT "approved", payment_source TEXT, cash_amount REAL NOT NULL DEFAULT 0, bank_amount REAL NOT NULL DEFAULT 0, personal_amount REAL NOT NULL DEFAULT 0, approved_at TEXT NOT NULL, paid_at TEXT, created_at TEXT NOT NULL, period_start TEXT, period_end TEXT, days_worked INTEGER NOT NULL DEFAULT 0, total_days_in_period INTEGER NOT NULL DEFAULT 30, prorated_base REAL NOT NULL DEFAULT 0, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS employee_allowances (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, name TEXT NOT NULL, amount REAL NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS employee_deductions (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, name TEXT NOT NULL, amount REAL NOT NULL, notes TEXT, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS employee_advances (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL, notes TEXT, is_settled INTEGER NOT NULL DEFAULT 0, payroll_id INTEGER, created_at TEXT NOT NULL, cash_amount REAL NOT NULL DEFAULT 0, bank_amount REAL NOT NULL DEFAULT 0, personal_amount REAL NOT NULL DEFAULT 0, entity_amount REAL NOT NULL DEFAULT 0, entity_hotel_id INTEGER, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE, FOREIGN KEY (payroll_id) REFERENCES payroll_records (id) ON DELETE SET NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS employee_events (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, event_type TEXT NOT NULL, event_date TEXT NOT NULL, reason TEXT, performed_by TEXT, notes TEXT, old_value TEXT, new_value TEXT, created_at TEXT NOT NULL, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS employee_documents (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER NOT NULL, type TEXT NOT NULL, name TEXT NOT NULL, expiry_date TEXT, notes TEXT, created_at TEXT NOT NULL, FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS financial_reports (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, date TEXT NOT NULL, income REAL NOT NULL, expenses REAL NOT NULL, notes TEXT, increase_desc TEXT, shortage_desc TEXT, employee_name TEXT, details_json TEXT, created_at TEXT NOT NULL, is_posted INTEGER NOT NULL DEFAULT 0, report_type TEXT NOT NULL DEFAULT "main", is_locked INTEGER NOT NULL DEFAULT 0, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS financial_accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, name TEXT NOT NULL, type TEXT NOT NULL, category TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS financial_ledger (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, account_id INTEGER NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, balance_before REAL NOT NULL, balance_after REAL NOT NULL, description TEXT NOT NULL, reference_id INTEGER, reference_type TEXT, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (account_id) REFERENCES financial_accounts (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS expense_categories (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, name TEXT NOT NULL, usage_count INTEGER NOT NULL DEFAULT 0, is_pinned INTEGER NOT NULL DEFAULT 0, is_basic INTEGER NOT NULL DEFAULT 0, is_visible INTEGER NOT NULL DEFAULT 1, icon_code INTEGER NOT NULL, color_value INTEGER NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS pending_expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, payment_method TEXT NOT NULL, category_id INTEGER NOT NULL, statement TEXT NOT NULL, notes TEXT, date TEXT NOT NULL, time TEXT NOT NULL, is_transferred INTEGER NOT NULL DEFAULT 0, amount_source TEXT NOT NULL DEFAULT "خارج النظام", created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (category_id) REFERENCES expense_categories (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS deposited_funds (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, report_id INTEGER, date TEXT NOT NULL, cash_amount REAL NOT NULL, network_amount REAL NOT NULL, cash_status TEXT NOT NULL DEFAULT "pending", network_status TEXT NOT NULL DEFAULT "pending", is_archived INTEGER NOT NULL DEFAULT 0, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (report_id) REFERENCES financial_reports (id) ON DELETE SET NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS settlement_accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, name TEXT NOT NULL, type TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS settlements (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, account_id INTEGER, creditor_hotel_id INTEGER, debtor_hotel_id INTEGER, amount REAL NOT NULL, date TEXT NOT NULL, description TEXT NOT NULL, attachments_json TEXT, status TEXT NOT NULL DEFAULT "open", total_paid REAL NOT NULL DEFAULT 0, direction TEXT, created_at TEXT NOT NULL, FOREIGN KEY (account_id) REFERENCES settlement_accounts (id) ON DELETE CASCADE, FOREIGN KEY (creditor_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (debtor_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS settlement_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, settlement_id INTEGER NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL, notes TEXT, amount_source TEXT NOT NULL DEFAULT "خارج النظام", FOREIGN KEY (settlement_id) REFERENCES settlements (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS invoices (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, invoice_number TEXT NOT NULL, date TEXT NOT NULL, company_name TEXT NOT NULL, tax_number TEXT NOT NULL, amount_before_tax REAL NOT NULL, vat REAL NOT NULL, total_amount REAL NOT NULL, facility_name TEXT NOT NULL, amount_source TEXT NOT NULL DEFAULT "خارج النظام", FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS suppliers (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, official_name TEXT NOT NULL, short_name TEXT NOT NULL, tax_number TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS contracts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, name TEXT NOT NULL, contractor_name TEXT NOT NULL, start_date TEXT NOT NULL, duration TEXT NOT NULL, end_date TEXT NOT NULL, total_value REAL NOT NULL, payment_method TEXT NOT NULL, status TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS contract_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, contract_id INTEGER NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL, status TEXT NOT NULL, amount_source TEXT NOT NULL DEFAULT "خارج النظام", FOREIGN KEY (contract_id) REFERENCES contracts (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS vault_balances (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, UNIQUE(hotel_id, type))');
    await db.execute('CREATE TABLE IF NOT EXISTS vault_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, balance_before REAL NOT NULL, balance_after REAL NOT NULL, reference TEXT, notes TEXT, source TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS personal_withdrawals (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, statement TEXT NOT NULL, method TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS entity_loans (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, statement TEXT NOT NULL, source TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
  }

  Future<void> _initializeData(Database db) async {
    final hotels = await db.query('hotels');
    for (var hotel in hotels) {
      final hId = hotel['id'] as int;
      await _initFinancialAccountsForHotel(db, hId);
      await _seedCategoriesForHotel(db, hId);
    }
  }

  Future<void> _initFinancialAccountsForHotel(Database db, int hId) async {
    await db.insert('financial_accounts', {'hotel_id': hId, 'name': 'الخزنة (نقد)', 'type': 'asset', 'category': 'cash', 'balance': 0.0});
    await db.insert('financial_accounts', {'hotel_id': hId, 'name': 'الحساب البنكي', 'type': 'asset', 'category': 'bank', 'balance': 0.0});
    await db.insert('financial_accounts', {'hotel_id': hId, 'name': 'الحساب الشخصي (المالك)', 'type': 'liability', 'category': 'personal', 'balance': 0.0});
    await db.insert('financial_accounts', {'hotel_id': hId, 'name': 'مستحقات من منشآت أخرى', 'type': 'asset', 'category': 'receivable_entity', 'balance': 0.0});
    await db.insert('financial_accounts', {'hotel_id': hId, 'name': 'ديون لمنشآت أخرى', 'type': 'liability', 'category': 'entity', 'balance': 0.0});
  }

  Future<void> _seedCategoriesForHotel(Database db, int hotelId) async {
    final cats = [{'n': 'رواتب', 'i': 0xe4f4, 'c': 0xFF4CAF50}, {'n': 'كهرباء', 'i': 0xe098, 'c': 0xFFFFEB3B}, {'n': 'مياه', 'i': 0xe6e4, 'c': 0xFF2196F3}, {'n': 'صيانة', 'i': 0xe1bd, 'c': 0xFFFF9800}, {'n': 'تأمينات', 'i': 0xe69a, 'c': 0xFF9C27B0}, {'n': 'إيجار', 'i': 0xe317, 'c': 0xFFF44336}, {'n': 'مشتريات', 'i': 0xe59c, 'c': 0xFF00BCD4}, {'n': 'نظافة', 'i': 0xe0bc, 'c': 0xFF009688}, {'n': 'وقود', 'i': 0xe3f1, 'c': 0xFF212121}, {'n': 'اتصالات', 'i': 0xe0cd, 'c': 0xFF3F51B5}, {'n': 'ضيافة', 'i': 0xe570, 'c': 0xFF795548}, {'n': 'أدوات مكتبية', 'i': 0xe190, 'c': 0xFF607D8B}, {'n': 'تشغيل', 'i': 0xe8b8, 'c': 0xFF455A64}, {'n': 'نقل', 'i': 0xe55b, 'c': 0xFF673AB7}];
    final now = DateTime.now().toIso8601String();
    for (var cat in cats) {
      await db.insert('expense_categories', {
        'hotel_id': hotelId, 'name': cat['n'], 'is_basic': 1,
        'icon_code': cat['i'], 'color_value': cat['c'], 'created_at': now
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // --- CRUD ---
  Future<List<Map<String, dynamic>>> getHotels() async { final db = await database; return await db.query('hotels'); }
  Future<int> insertHotel(Map<String, dynamic> data) async { final db = await database; final id = await db.insert('hotels', data); await _initFinancialAccountsForHotel(db, id); await _seedCategoriesForHotel(db, id); return id; }
  Future<int> updateHotel(Map<String, dynamic> data, int id) async { final db = await database; return await db.update('hotels', data, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteHotel(int id) async { final db = await database; return await db.delete('hotels', where: 'id = ?', whereArgs: [id]); }

  Future<int> insertFinancialReport(Map<String, dynamic> data) async { final db = await database; return await db.insert('financial_reports', data); }
  Future<List<Map<String, dynamic>>> getFinancialReports({required int hotelId}) async { final db = await database; return await db.query('financial_reports', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'date DESC'); }
  Future<List<Map<String, dynamic>>> getUnpostedReports(int hotelId) async { final db = await database; return await db.query('financial_reports', where: 'hotel_id = ? AND is_posted = 0', whereArgs: [hotelId], orderBy: 'date DESC'); }
  Future<Map<String, dynamic>?> getMainReportForDate(int hotelId, String date) async {
    final db = await database;
    final results = await db.query('financial_reports', where: 'hotel_id = ? AND date = ? AND report_type = "main"', whereArgs: [hotelId, date], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getExpenseCategories(int hotelId) async { final db = await database; return await db.query('expense_categories', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'is_pinned DESC, sort_order ASC'); }
  Future<int> insertExpenseCategory(Map<String, dynamic> data) async { final db = await database; return await db.insert('expense_categories', data); }

  Future<List<Map<String, dynamic>>> getPendingExpenses({required int hotelId, bool? isTransferred}) async {
    final db = await database;
    String where = 'pe.hotel_id = ?'; List<dynamic> args = [hotelId];
    if (isTransferred != null) { where += ' AND pe.is_transferred = ?'; args.add(isTransferred ? 1 : 0); }
    return await db.rawQuery('SELECT pe.*, ec.name as category_name, ec.icon_code, ec.color_value FROM pending_expenses pe JOIN expense_categories ec ON pe.category_id = ec.id WHERE $where ORDER BY pe.date DESC, pe.time DESC', args);
  }
  Future<int> insertPendingExpense(Map<String, dynamic> data) async { final db = await database; await db.execute('UPDATE expense_categories SET usage_count = usage_count + 1 WHERE id = ?', [data['category_id']]); return await db.insert('pending_expenses', data); }
  Future<void> transferPendingExpenses(List<int> ids) async { final db = await database; await db.transaction((txn) async { for (var id in ids) { await txn.update('pending_expenses', {'is_transferred': 1}, where: 'id = ?', whereArgs: [id]); } }); }

  Future<List<Map<String, dynamic>>> getNotes(int hotelId) async { final db = await database; return await db.query('notes', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'created_at DESC'); }
  Future<int> insertNote(Map<String, dynamic> data) async { final db = await database; return await db.insert('notes', data); }

  Future<List<Map<String, dynamic>>> getDocuments(int hotelId) async { final db = await database; return await db.query('documents', where: 'hotel_id = ?', whereArgs: [hotelId]); }
  Future<int> insertDocument(Map<String, dynamic> data) async { final db = await database; return await db.insert('documents', data); }

  Future<List<Map<String, dynamic>>> getEmployees(int hotelId, {bool includeArchived = false}) async {
    final db = await database;
    String where = 'hotel_id = ?'; List<dynamic> args = [hotelId];
    if (!includeArchived) where += ' AND (is_archived IS NULL OR is_archived = 0)';
    return await db.query('employees', where: where, whereArgs: args, orderBy: 'name ASC');
  }
  Future<List<Map<String, dynamic>>> getArchivedEmployees(int hotelId) async { final db = await database; return await db.query('employees', where: 'hotel_id = ? AND is_archived = 1', whereArgs: [hotelId], orderBy: 'name ASC'); }
  Future<Map<String, dynamic>?> getEmployeeById(int id) async { final db = await database; final res = await db.query('employees', where: 'id = ?', whereArgs: [id], limit: 1); return res.isNotEmpty ? res.first : null; }

  /// يُنشئ الموظف ثم يولّد له رقماً وظيفياً ثابتاً (EMP-000001) مشتقاً من المعرّف الدائم لسجله.
  Future<int> insertEmployee(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('employees', data);
    final number = 'EMP-${id.toString().padLeft(6, '0')}';
    await db.update('employees', {'employee_number': number}, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<List<Map<String, dynamic>>> getEmployeeAllowances(int employeeId) async { final db = await database; return await db.query('employee_allowances', where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'id DESC'); }
  Future<int> insertEmployeeAllowance(Map<String, dynamic> data) async { final db = await database; return await db.insert('employee_allowances', data); }

  Future<List<Map<String, dynamic>>> getEmployeeDeductions(int employeeId) async { final db = await database; return await db.query('employee_deductions', where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'id DESC'); }
  Future<int> insertEmployeeDeduction(Map<String, dynamic> data) async { final db = await database; return await db.insert('employee_deductions', data); }

  Future<List<Map<String, dynamic>>> getEmployeeAdvances(int employeeId) async { final db = await database; return await db.query('employee_advances', where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'date DESC, id DESC'); }
  Future<int> insertEmployeeAdvance(Map<String, dynamic> data) async { final db = await database; return await db.insert('employee_advances', data); }

  Future<List<Map<String, dynamic>>> getEmployeeAllowancesByHotel(int hotelId) async { final db = await database; return await db.rawQuery('SELECT ea.*, e.name as employee_name FROM employee_allowances ea JOIN employees e ON ea.employee_id = e.id WHERE ea.hotel_id = ? ORDER BY ea.created_at DESC', [hotelId]); }
  Future<List<Map<String, dynamic>>> getEmployeeDeductionsByHotel(int hotelId) async { final db = await database; return await db.rawQuery('SELECT ed.*, e.name as employee_name FROM employee_deductions ed JOIN employees e ON ed.employee_id = e.id WHERE ed.hotel_id = ? ORDER BY ed.created_at DESC', [hotelId]); }
  Future<List<Map<String, dynamic>>> getEmployeeAdvancesByHotel(int hotelId) async { final db = await database; return await db.rawQuery('SELECT ea.*, e.name as employee_name FROM employee_advances ea JOIN employees e ON ea.employee_id = e.id WHERE ea.hotel_id = ? ORDER BY ea.date DESC', [hotelId]); }

  Future<List<Map<String, dynamic>>> getPayrollRecords({required int hotelId, int? employeeId, String? startPeriod, String? endPeriod}) async {
    final db = await database;
    String where = 'hotel_id = ?'; List<dynamic> args = [hotelId];
    if (employeeId != null) { where += ' AND employee_id = ?'; args.add(employeeId); }
    if (startPeriod != null) { where += ' AND period >= ?'; args.add(startPeriod); }
    if (endPeriod != null) { where += ' AND period <= ?'; args.add(endPeriod); }
    return await db.query('payroll_records', where: where, whereArgs: args, orderBy: 'period DESC, id DESC');
  }
  Future<Map<String, dynamic>?> getLatestPayrollForEmployee(int employeeId) async { final db = await database; final res = await db.query('payroll_records', where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'id DESC', limit: 1); return res.isNotEmpty ? res.first : null; }
  /// كل رواتب موظف معيّن بلا قيد فندق — يشمل فترات عمله في كل الفنادق التي تنقّل بينها.
  Future<List<Map<String, dynamic>>> getPayrollRecordsByEmployee(int employeeId) async { final db = await database; return await db.query('payroll_records', where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'period DESC, id DESC'); }

  /// ينشئ سجل رواتب معتمد (اعتماد الرواتب) ويقفل السلف غير المسددة على هذا السجل، ضمن معاملة واحدة.
  Future<int> approvePayroll(Map<String, dynamic> payrollData, List<int> advanceIdsToSettle) async {
    final db = await database;
    return await db.transaction((txn) async {
      final payrollId = await txn.insert('payroll_records', payrollData);
      for (var advId in advanceIdsToSettle) {
        await txn.update('employee_advances', {'is_settled': 1, 'payroll_id': payrollId}, where: 'id = ?', whereArgs: [advId]);
      }
      return payrollId;
    });
  }

  /// يتحقق من وجود أي بيانات مالية للموظف (بدلات/خصومات/سلف/رواتب) لمنع حذفه.
  Future<bool> employeeHasFinancialRecords(int employeeId) async {
    final db = await database;
    for (var table in ['employee_allowances', 'employee_deductions', 'employee_advances', 'payroll_records']) {
      final res = await db.query(table, where: 'employee_id = ?', whereArgs: [employeeId], limit: 1);
      if (res.isNotEmpty) return true;
    }
    return false;
  }

  // --- سجل حركة الموظف (Event Log) ---
  Future<List<Map<String, dynamic>>> getEmployeeEvents(int employeeId) async { final db = await database; return await db.query('employee_events', where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'event_date DESC, id DESC'); }
  Future<List<Map<String, dynamic>>> getEmployeeEventsByHotel(int hotelId, {String? eventType}) async { final db = await database; final where = <String>['ev.hotel_id = ?']; final args = <dynamic>[hotelId]; if (eventType != null) { where.add('ev.event_type = ?'); args.add(eventType); } return await db.rawQuery('SELECT ev.*, e.name as employee_name FROM employee_events ev JOIN employees e ON ev.employee_id = e.id WHERE ${where.join(' AND ')} ORDER BY ev.event_date DESC, ev.id DESC', args); }
  Future<int> insertEmployeeEvent(Map<String, dynamic> data) async { final db = await database; return await db.insert('employee_events', data); }

  /// نقل الموظف بين الفنادق: يحدّث الفندق الحالي للموظف ويسجّل حركة "نقل" ضمن معاملة واحدة.
  /// السجل نفسه لا يُستنسخ ولا يُحذف — تبقى بياناته السابقة (بدلات/خصومات/سلف/رواتب/مستندات) كما هي مرتبطة برقمه الوظيفي.
  Future<void> transferEmployee({required int employeeId, required int newHotelId, required Map<String, dynamic> eventData}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('employees', {'hotel_id': newHotelId}, where: 'id = ?', whereArgs: [employeeId]);
      await txn.insert('employee_events', eventData);
    });
  }

  /// تغيير حالة الموظف (إيقاف/عودة/استقالة/إنهاء خدمة...) مع تسجيل الحركة، ضمن معاملة واحدة.
  Future<void> applyEmployeeStatusChange({required int employeeId, required String newStatus, required Map<String, dynamic> eventData}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('employees', {'status': newStatus}, where: 'id = ?', whereArgs: [employeeId]);
      await txn.insert('employee_events', eventData);
    });
  }

  /// تعديل الراتب الأساسي أو الوظيفة مع تسجيل القيمة القديمة والجديدة، ضمن معاملة واحدة.
  Future<void> applyEmployeeFieldChange({required int employeeId, required Map<String, dynamic> fieldUpdate, required Map<String, dynamic> eventData}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('employees', fieldUpdate, where: 'id = ?', whereArgs: [employeeId]);
      await txn.insert('employee_events', eventData);
    });
  }

  /// أرشفة الموظف بدل حذفه، مع تسجيل حركة إنهاء/أرشفة.
  Future<void> archiveEmployee({required int employeeId, required Map<String, dynamic> eventData}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('employees', {'is_archived': 1}, where: 'id = ?', whereArgs: [employeeId]);
      await txn.insert('employee_events', eventData);
    });
  }

  // --- مستندات الموظف (تنتقل معه، غير مرتبطة بفندق) ---
  Future<List<Map<String, dynamic>>> getEmployeeDocuments(int employeeId) async { final db = await database; return await db.query('employee_documents', where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'expiry_date ASC'); }
  Future<int> insertEmployeeDocument(Map<String, dynamic> data) async { final db = await database; return await db.insert('employee_documents', data); }

  Future<List<Map<String, dynamic>>> getInvoices(int hotelId) async { final db = await database; return await db.query('invoices', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'id DESC'); }
  Future<int> insertInvoice(Map<String, dynamic> data) async { final db = await database; return await db.insert('invoices', data); }
  Future<List<Map<String, dynamic>>> getInvoicesBySupplier({required int hotelId, required String companyName, String? startDate, String? endDate}) async { final db = await database; String where = 'hotel_id = ? AND company_name = ?'; List<dynamic> args = [hotelId, companyName]; if (startDate != null) { where += ' AND date >= ?'; args.add(startDate); } if (endDate != null) { where += ' AND date <= ?'; args.add(endDate); } return await db.query('invoices', where: where, whereArgs: args, orderBy: 'date DESC'); }
  Future<List<Map<String, dynamic>>> getFilteredInvoices({required int hotelId, String? startDate, String? endDate}) async { final db = await database; String where = 'hotel_id = ?'; List<dynamic> args = [hotelId]; if (startDate != null) { where += ' AND date >= ?'; args.add(startDate); } if (endDate != null) { where += ' AND date <= ?'; args.add(endDate); } return await db.query('invoices', where: where, whereArgs: args, orderBy: 'date DESC'); }

  Future<int> insertSupplier(Map<String, dynamic> data) async { final db = await database; return await db.insert('suppliers', data); }
  Future<Map<String, dynamic>?> getSupplierByOfficialName(int hotelId, String name) async { final db = await database; final res = await db.query('suppliers', where: 'hotel_id = ? AND official_name = ?', whereArgs: [hotelId, name], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<List<Map<String, dynamic>>> searchSuppliers(int hotelId, String query) async { final db = await database; return await db.query('suppliers', where: 'hotel_id = ? AND (official_name LIKE ? OR short_name LIKE ?)', whereArgs: [hotelId, "%$query%", "%$query%"], limit: 10); }

  Future<List<Map<String, dynamic>>> getContracts(int hotelId) async { final db = await database; return await db.query('contracts', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'id DESC'); }
  Future<int> insertContract(Map<String, dynamic> data) async { final db = await database; return await db.insert('contracts', data); }
  Future<void> insertContractWithPayments(Map<String, dynamic> cd, List<Map<String, dynamic>> pd) async { final db = await database; await db.transaction((txn) async { final cId = await txn.insert('contracts', cd); for (var p in pd) { p['contract_id'] = cId; await txn.insert('contract_payments', p); } }); }
  Future<List<Map<String, dynamic>>> getContractPayments(int cId) async { final db = await database; return await db.query('contract_payments', where: 'contract_id = ?', whereArgs: [cId], orderBy: 'date ASC'); }
  Future<int> insertContractPayment(Map<String, dynamic> data) async { final db = await database; return await db.insert('contract_payments', data); }

  Future<Map<String, double>> getVaultBalances(int hotelId) async { final db = await database; final res = await db.query('vault_balances', where: 'hotel_id = ?', whereArgs: [hotelId]); Map<String, double> b = {'cash': 0.0, 'bank': 0.0}; if (res.isEmpty) { await db.insert('vault_balances', {'hotel_id': hotelId, 'type': 'cash', 'balance': 0.0}); await db.insert('vault_balances', {'hotel_id': hotelId, 'type': 'bank', 'balance': 0.0}); return b; } for (var r in res) { b[r['type'] as String] = (r['balance'] as num).toDouble(); } return b; }
  Future<List<Map<String, dynamic>>> getVaultTransactions(int hotelId) async { final db = await database; return await db.query('vault_transactions', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'id DESC'); }
  Future<int> insertVaultTransaction(Map<String, dynamic> data) async { final db = await database; return await db.transaction((txn) async { final hId = data['hotel_id']; final type = data['source'] == 'الحساب البنكي' ? 'bank' : 'cash'; final nB = (data['balance_after'] as num).toDouble(); await txn.update('vault_balances', {'balance': nB}, where: 'hotel_id = ? AND type = ?', whereArgs: [hId, type]); return await txn.insert('vault_transactions', data); }); }

  Future<List<Map<String, dynamic>>> getDepositedFunds({required int hotelId, bool? isArchived}) async { final db = await database; String w = 'hotel_id = ?'; List<dynamic> args = [hotelId]; if (isArchived != null) { w += ' AND is_archived = ?'; args.add(isArchived ? 1 : 0); } return await db.query('deposited_funds', where: w, whereArgs: args, orderBy: 'date DESC'); }
  Future<int> insertDepositedFund(Map<String, dynamic> data) async { final db = await database; return await db.insert('deposited_funds', data); }
  Future<int> updateDepositedFund(Map<String, dynamic> data, int id) async { final db = await database; return await db.update('deposited_funds', data, where: 'id = ?', whereArgs: [id]); }
  Future<Map<String, dynamic>?> getDepositedFundByReportId(int reportId) async { final db = await database; final res = await db.query('deposited_funds', where: 'report_id = ?', whereArgs: [reportId], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<int> updateDepositedFundByReportId(Map<String, dynamic> data, int reportId) async { final db = await database; return await db.update('deposited_funds', data, where: 'report_id = ?', whereArgs: [reportId]); }

  Future<List<Map<String, dynamic>>> getPersonalWithdrawals(int hotelId) async { final db = await database; return await db.query('personal_withdrawals', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'date DESC, time DESC'); }
  Future<int> insertPersonalWithdrawal(Map<String, dynamic> data) async { final db = await database; return await db.insert('personal_withdrawals', data); }

  Future<List<Map<String, dynamic>>> getEntityLoans(int hotelId) async { final db = await database; return await db.query('entity_loans', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'date DESC, time DESC'); }
  Future<int> insertEntityLoan(Map<String, dynamic> data) async { final db = await database; return await db.insert('entity_loans', data); }

  Future<int> insertSettlementAccount(Map<String, dynamic> data) async { final db = await database; return await db.insert('settlement_accounts', data); }
  Future<List<Map<String, dynamic>>> getSettlementAccounts({required int hotelId, String? type}) async { final db = await database; String w = 'hotel_id = ?'; List<dynamic> args = [hotelId]; if (type != null) { w += ' AND type = ?'; args.add(type); } return await db.query('settlement_accounts', where: w, whereArgs: args); }
  Future<Map<String, dynamic>?> getSettlementAccountByName(int hotelId, String name, String type) async { final db = await database; final res = await db.query('settlement_accounts', where: 'hotel_id = ? AND name = ? AND type = ?', whereArgs: [hotelId, name, type], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<int> insertSettlement(Map<String, dynamic> data) async { final db = await database; return await db.insert('settlements', data); }
  Future<List<Map<String, dynamic>>> getSettlements({String? type, int? accountId, int? creditorHotelId, int? debtorHotelId, int? hotelId}) async { final db = await database; String w = '1=1'; List<dynamic> args = []; if (type != null) { w += ' AND type = ?'; args.add(type); } if (accountId != null) { w += ' AND account_id = ?'; args.add(accountId); } if (creditorHotelId != null) { w += ' AND creditor_hotel_id = ?'; args.add(creditorHotelId); } if (debtorHotelId != null) { w += ' AND debtor_hotel_id = ?'; args.add(debtorHotelId); } if (hotelId != null) { w += ' AND (creditor_hotel_id = ? OR debtor_hotel_id = ?)'; args.addAll([hotelId, hotelId]); } return await db.query('settlements', where: w, whereArgs: args, orderBy: 'date DESC'); }
  Future<int> updateSettlement(Map<String, dynamic> data, int id) async { final db = await database; return await db.update('settlements', data, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteSettlement(int id) async { final db = await database; return await db.delete('settlements', where: 'id = ?', whereArgs: [id]); }
  Future<int> insertSettlementTransaction(Map<String, dynamic> data) async { final db = await database; return await db.transaction((txn) async { final id = await txn.insert('settlement_transactions', data); final sId = data['settlement_id']; final trans = await txn.query('settlement_transactions', where: 'settlement_id = ?', whereArgs: [sId]); double tp = 0; for (var t in trans) { tp += (t['amount'] as num).toDouble(); } final s = await txn.query('settlements', where: 'id = ?', whereArgs: [sId]); if (s.isNotEmpty) { final amt = (s.first['amount'] as num).toDouble(); final status = tp >= amt ? 'paid' : 'open'; await txn.update('settlements', {'total_paid': tp, 'status': status}, where: 'id = ?', whereArgs: [sId]); } return id; }); }
  Future<List<Map<String, dynamic>>> getSettlementTransactions(int sId) async { final db = await database; return await db.query('settlement_transactions', where: 'settlement_id = ?', whereArgs: [sId], orderBy: 'date DESC'); }
  Future<int> deleteSettlementTransaction(int id, int sId) async { final db = await database; return await db.transaction((txn) async { final res = await txn.delete('settlement_transactions', where: 'id = ?', whereArgs: [id]); final trans = await txn.query('settlement_transactions', where: 'settlement_id = ?', whereArgs: [sId]); double tp = 0; for (var t in trans) { tp += (t['amount'] as num).toDouble(); } final s = await txn.query('settlements', where: 'id = ?', whereArgs: [sId]); if (s.isNotEmpty) { final amt = (s.first['amount'] as num).toDouble(); final status = tp >= amt ? 'paid' : 'open'; await txn.update('settlements', {'total_paid': tp, 'status': status}, where: 'id = ?', whereArgs: [sId]); } return res; }); }

  Future<int> deleteById(String table, int id) async { final db = await database; return await db.delete(table, where: 'id = ?', whereArgs: [id]); }
  Future<int> updateById(String table, Map<String, dynamic> data, int id) async { final db = await database; return await db.update(table, data, where: 'id = ?', whereArgs: [id]); }

  Future<List<Map<String, dynamic>>> getFinancialAccounts(int hotelId) async { final db = await database; return await db.query('financial_accounts', where: 'hotel_id = ?', whereArgs: [hotelId]); }
  Future<List<Map<String, dynamic>>> getPeopleAccounts(int hotelId) async { final db = await database; return await db.query('financial_accounts', where: 'hotel_id = ? AND category LIKE ?', whereArgs: [hotelId, 'person_%']); }
  Future<Map<String, dynamic>?> getFinancialAccountByCategory(int hotelId, String cat) async { final db = await database; final res = await db.query('financial_accounts', where: 'hotel_id = ? AND category = ?', whereArgs: [hotelId, cat], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<int> updateFinancialAccountBalance(int accId, double bal) async { final db = await database; return await db.update('financial_accounts', {'balance': bal}, where: 'id = ?', whereArgs: [accId]); }
  Future<int> insertLedgerEntry(Map<String, dynamic> data) async { final db = await database; return await db.insert('financial_ledger', data); }
  Future<List<Map<String, dynamic>>> getLedgerByAccount(int hotelId, String category) async { final db = await database; if (category == 'all') { return await db.query('financial_ledger', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'date DESC, time DESC'); } return await db.rawQuery('SELECT fl.* FROM financial_ledger fl JOIN financial_accounts fa ON fl.account_id = fa.id WHERE fl.hotel_id = ? AND fa.category = ? ORDER BY fl.date DESC, fl.time DESC', [hotelId, category]); }
}
