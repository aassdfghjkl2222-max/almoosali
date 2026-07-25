import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../app_preferences.dart';

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

  /// اسم ملف قاعدة البيانات النشط: النسخة التدريبية المنفصلة أثناء وضع
  /// التدريب، أو الملف الحقيقي في كل الأحوال الأخرى. راجع TrainingModeService.
  Future<String> _activeDbFileName() async {
    final trainingActive = await AppPreferences.getBool(AppPreferences.keyTrainingModeActive);
    return trainingActive ? 'manazel_training.db' : 'manazel.db';
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), await _activeDbFileName());
    return await openDatabase(
      path,
      version: 45, // Upgrade to v45: وحدة إدارة الفنادق الكاملة (حقول تفصيلية + سجل تدقيق)
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
        if (oldVersion < 25) {
          try { await db.execute('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL UNIQUE, full_name TEXT NOT NULL, password TEXT NOT NULL, role_id TEXT, is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS permission_groups (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, permissions_json TEXT NOT NULL DEFAULT "[]", created_at TEXT NOT NULL)'); } catch (_) {}
          try { await _seedDefaultUsers(db); } catch (_) {}
        }
        if (oldVersion < 26) {
          try { await db.execute('ALTER TABLE invoices ADD COLUMN expense_category TEXT'); } catch (_) {}
        }
        if (oldVersion < 27) {
          try { await db.execute('ALTER TABLE suppliers ADD COLUMN notes TEXT'); } catch (_) {}
        }
        if (oldVersion < 28) {
          try { await db.execute('ALTER TABLE invoices ADD COLUMN payment_method TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE invoices ADD COLUMN related_hotel_id INTEGER'); } catch (_) {}
        }
        if (oldVersion < 29) {
          try { await db.execute('CREATE TABLE IF NOT EXISTS supplier_debts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, supplier_id INTEGER NOT NULL, invoice_id INTEGER NOT NULL UNIQUE, amount REAL NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE, FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE)'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS supplier_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, supplier_id INTEGER NOT NULL, amount REAL NOT NULL, method TEXT, date TEXT NOT NULL, notes TEXT, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE)'); } catch (_) {}
        }
        if (oldVersion < 30) {
          try { await db.execute('CREATE TABLE IF NOT EXISTS invoice_attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, file_path TEXT NOT NULL, file_type TEXT NOT NULL, file_name TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)'); } catch (_) {}
          // بلا FOREIGN KEY على invoice_id عمداً — يجب أن يبقى سجل التعديلات موجوداً حتى بعد حذف الفاتورة نفسها (لا يُسمح بحذف سجل التعديلات).
          try { await db.execute('CREATE TABLE IF NOT EXISTS invoice_audit_log (id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, username TEXT NOT NULL, operation_type TEXT NOT NULL, changed_fields TEXT, occurred_at TEXT NOT NULL)'); } catch (_) {}
        }
        if (oldVersion < 31) {
          try { await db.execute('ALTER TABLE expense_categories ADD COLUMN short_code TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE expense_categories ADD COLUMN is_default INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
          try { await _unifyExpenseCategories(db); } catch (_) {}
        }
        if (oldVersion < 32) {
          try { await db.execute('CREATE TABLE IF NOT EXISTS document_categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, color_value INTEGER NOT NULL, created_at TEXT NOT NULL)'); } catch (_) {}
          try { await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_categories_name ON document_categories(name)'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS document_types (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT, category_id INTEGER NOT NULL, is_mandatory INTEGER NOT NULL DEFAULT 0, requires_renewal INTEGER NOT NULL DEFAULT 0, scope TEXT NOT NULL DEFAULT "all", is_active INTEGER NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, FOREIGN KEY (category_id) REFERENCES document_categories (id))'); } catch (_) {}
          try { await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_types_name ON document_types(name)'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS document_type_hotels (id INTEGER PRIMARY KEY AUTOINCREMENT, document_type_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, FOREIGN KEY (document_type_id) REFERENCES document_types (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)'); } catch (_) {}
          try { await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_type_hotels ON document_type_hotels(document_type_id, hotel_id)'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS document_attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, file_path TEXT NOT NULL, file_type TEXT NOT NULL, file_name TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)'); } catch (_) {}
          try { await db.execute('ALTER TABLE documents ADD COLUMN document_type_id INTEGER'); } catch (_) {}
          try { await db.execute('ALTER TABLE documents ADD COLUMN document_number TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE documents ADD COLUMN issue_date TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE documents ADD COLUMN issuing_authority TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE documents ADD COLUMN notes TEXT'); } catch (_) {}
          try { await _seedGlobalDocumentCategories(db); } catch (_) {}
          try { await _provisionDocumentTypesForAllHotels(db); } catch (_) {}
        }
        if (oldVersion < 33) {
          try { await db.execute('ALTER TABLE documents ADD COLUMN owner_type TEXT NOT NULL DEFAULT "hotel"'); } catch (_) {}
          try { await db.execute('ALTER TABLE documents ADD COLUMN owner_id INTEGER'); } catch (_) {}
          try { await db.execute('UPDATE documents SET owner_id = hotel_id WHERE owner_id IS NULL'); } catch (_) {}
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_owner ON documents(owner_type, owner_id)'); } catch (_) {}
          try { await _migrateEmployeeDocuments(db); } catch (_) {}
        }
        if (oldVersion < 34) {
          try { await db.execute('ALTER TABLE document_types ADD COLUMN lifecycle TEXT NOT NULL DEFAULT "permanent"'); } catch (_) {}
        }
        if (oldVersion < 35) {
          try { await db.execute('ALTER TABLE documents ADD COLUMN hotel_scope TEXT NOT NULL DEFAULT "single"'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS document_hotels (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)'); } catch (_) {}
          try { await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_hotels ON document_hotels(document_id, hotel_id)'); } catch (_) {}
          try { await db.execute('CREATE TABLE IF NOT EXISTS document_folder_links (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL, document_type_id INTEGER NOT NULL, FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE, FOREIGN KEY (document_type_id) REFERENCES document_types (id) ON DELETE CASCADE)'); } catch (_) {}
          try { await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_folder_links ON document_folder_links(document_id, document_type_id)'); } catch (_) {}
          try { await _migratePermanentFolderLinks(db); } catch (_) {}
        }
        if (oldVersion < 36) {
          try { await db.execute('ALTER TABLE pending_expenses ADD COLUMN supplier_id INTEGER'); } catch (_) {}
          try { await db.execute('ALTER TABLE pending_expenses ADD COLUMN due_date TEXT'); } catch (_) {}
          try {
            await db.execute(
              'CREATE TABLE IF NOT EXISTS pending_expense_debts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, supplier_id INTEGER NOT NULL, pending_expense_id INTEGER NOT NULL UNIQUE, amount REAL NOT NULL, statement TEXT NOT NULL, due_date TEXT, status TEXT NOT NULL DEFAULT "غير مسدد", created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (supplier_id) REFERENCES suppliers (id), FOREIGN KEY (pending_expense_id) REFERENCES pending_expenses (id) ON DELETE CASCADE)',
            );
          } catch (_) {}
          try {
            await db.execute(
              'CREATE TABLE IF NOT EXISTS pending_expense_attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, pending_expense_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, file_path TEXT NOT NULL, file_type TEXT NOT NULL, file_name TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (pending_expense_id) REFERENCES pending_expenses (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)',
            );
          } catch (_) {}
        }
        if (oldVersion < 37) {
          try {
            await db.execute(
              'CREATE TABLE IF NOT EXISTS financial_report_items (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, type TEXT NOT NULL, default_funding_source TEXT, is_visible INTEGER NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)',
            );
          } catch (_) {}
          try { await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_financial_report_items_name_type ON financial_report_items(name, type)'); } catch (_) {}
        }
        if (oldVersion < 38) {
          try { await db.execute('ALTER TABLE deposited_funds ADD COLUMN posted_at TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE deposited_funds ADD COLUMN posted_by TEXT'); } catch (_) {}
        }
        if (oldVersion < 39) {
          try { await db.execute('ALTER TABLE suppliers ADD COLUMN default_expense_category TEXT'); } catch (_) {}
        }
        if (oldVersion < 40) {
          try { await db.execute('ALTER TABLE pending_expenses ADD COLUMN funding_source_hotel_id INTEGER'); } catch (_) {}
        }
        if (oldVersion < 41) {
          try {
            await db.execute(
              'CREATE TABLE IF NOT EXISTS shared_expense_groups (id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, category_id INTEGER NOT NULL, total_amount REAL NOT NULL, payment_method TEXT NOT NULL, funding_hotel_id INTEGER NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (category_id) REFERENCES expense_categories (id), FOREIGN KEY (funding_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)',
            );
          } catch (_) {}
          try {
            await db.execute(
              'CREATE TABLE IF NOT EXISTS shared_expense_shares (id INTEGER PRIMARY KEY AUTOINCREMENT, shared_expense_group_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, FOREIGN KEY (shared_expense_group_id) REFERENCES shared_expense_groups (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)',
            );
          } catch (_) {}
        }
        if (oldVersion < 42) {
          try {
            await db.execute(
              'CREATE TABLE IF NOT EXISTS advance_withdrawals (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, statement TEXT NOT NULL, method TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)',
            );
          } catch (_) {}
        }
        if (oldVersion < 43) {
          // توحيد وسيلة الدفع: "بنك" لم تعد وسيلة دفع مستقلة، كل ما هو غير نقدي أصبح "شبكة".
          // يُطبَّق فقط على حقول "وسيلة الدفع/السحب" الفعلية، وليس على بند إيراد "التحويل البنكي"
          // في التقرير اليومي (financial_reports.details_json['transfer']) الذي يبقى تصنيفاً مستقلاً.
          try { await db.execute("UPDATE personal_withdrawals SET method = 'شبكة' WHERE method = 'حساب بنكي'"); } catch (_) {}
          try { await db.execute("UPDATE entity_loans SET source = 'شبكة' WHERE source = 'حساب بنكي'"); } catch (_) {}
          try { await db.execute("UPDATE vault_transactions SET source = 'شبكة' WHERE source = 'الحساب البنكي'"); } catch (_) {}
          try { await db.execute("UPDATE invoices SET payment_method = 'شبكة' WHERE payment_method = 'بنك'"); } catch (_) {}
          try { await db.execute("UPDATE shared_expense_groups SET payment_method = 'شبكة' WHERE payment_method = 'تحويل بنكي'"); } catch (_) {}
          try { await db.execute("UPDATE payroll_records SET payment_source = 'شبكة' WHERE payment_source = 'بنك'"); } catch (_) {}
          // "التحويل بين المنشآت": تحويل مباشر لمبلغ بين فندقين (بلا مصروف مرتبط) —
          // نفس نمط advance_withdrawals/shared_expense_groups (جدول تتبّع/عرض فقط، القيد
          // المحاسبي الفعلي عبر FinancialEngine.recordTransaction بآلية entity_/receivable_entity).
          try {
            await db.execute(
              'CREATE TABLE IF NOT EXISTS inter_entity_transfers (id INTEGER PRIMARY KEY AUTOINCREMENT, from_hotel_id INTEGER NOT NULL, to_hotel_id INTEGER NOT NULL, amount REAL NOT NULL, statement TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (from_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (to_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)',
            );
          } catch (_) {}
        }
        if (oldVersion < 44) {
          // أرشفة الفنادق: العمود hotels.active موجود أصلاً منذ سنوات لكنه لم
          // يُستخدَم فعلياً في أي استعلام (كل الفنادق كانت active=1 دائماً) —
          // أُعيد استخدامه الآن كعلم "غير مؤرشَف" بدل إضافة عمود جديد مكرِّر
          // لنفس المعنى. archived_at/archived_by جديدان فقط لعرض سجل الأرشيف.
          try { await db.execute('ALTER TABLE hotels ADD COLUMN archived_at TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN archived_by TEXT'); } catch (_) {}
        }
        if (oldVersion < 45) {
          // وحدة إدارة الفنادق: حقول تفصيلية (عامة/موقع/تواصل/معلومات الفندق) +
          // "status" كتصنيف تشغيلي أدق من active (نشط/غير نشط/تحت الصيانة/قريباً)
          // بينما يبقى active كما هو تماماً علم "غير مؤرشَف" الوحيد المستخدَم في
          // استعلامات القوائم (بلا أي تغيير على منطقه الحالي) — الأرشفة تضبط
          // active=0 وstatus='archived' معاً. logo/cover/الإعدادات الإقليمية
          // حقول مُعَدَّة للمستقبل فقط (راجع تعليقات Hotel model)، لا تُقرأ بعد
          // من أي شاشة أخرى في التطبيق.
          try { await db.execute("ALTER TABLE hotels ADD COLUMN status TEXT NOT NULL DEFAULT 'active'"); } catch (_) {}
          try { await db.execute("UPDATE hotels SET status = 'archived' WHERE active = 0"); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN archive_reason TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN hotel_code TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN description TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN country TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN district TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN address TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN maps_link TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN phone TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN mobile TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN whatsapp TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN email TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN website TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN star_rating INTEGER'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN rooms_count INTEGER'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN opening_date TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN notes TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN secondary_color_value INTEGER'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN logo_path TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN cover_image_path TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN currency TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN language TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN time_zone TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN date_format TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE hotels ADD COLUMN time_format TEXT'); } catch (_) {}
          // سجل تدقيق الفنادق — بلا FOREIGN KEY عمداً (نفس نمط invoice_audit_log
          // تماماً): يجب أن يبقى السجل موجوداً حتى بعد حذف الفندق نهائياً، فلا
          // يُسمح بحذفه تبعاً لحذف الفندق. hotel_name مخزَّن مباشرة (وليس عبر
          // JOIN) ليبقى السجل مقروءاً حتى بعد زوال سجل الفندق نفسه.
          try {
            await db.execute(
              'CREATE TABLE IF NOT EXISTS hotel_audit_log (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, hotel_name TEXT NOT NULL, action TEXT NOT NULL, performed_by TEXT NOT NULL, details TEXT, created_at TEXT NOT NULL)',
            );
          } catch (_) {}
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
      if (!await hasColumn('hotels', 'archived_at')) {
        await db.execute('ALTER TABLE hotels ADD COLUMN archived_at TEXT');
      }
      if (!await hasColumn('hotels', 'archived_by')) {
        await db.execute('ALTER TABLE hotels ADD COLUMN archived_by TEXT');
      }
      if (!await hasColumn('hotels', 'status')) {
        await db.execute("ALTER TABLE hotels ADD COLUMN status TEXT NOT NULL DEFAULT 'active'");
        try { await db.execute("UPDATE hotels SET status = 'archived' WHERE active = 0"); } catch (_) {}
      }
      for (final col in const [
        'archive_reason', 'hotel_code', 'description', 'country', 'district', 'address', 'maps_link',
        'phone', 'mobile', 'whatsapp', 'email', 'website', 'opening_date', 'notes',
        'logo_path', 'cover_image_path', 'currency', 'language', 'time_zone', 'date_format', 'time_format',
      ]) {
        if (!await hasColumn('hotels', col)) {
          await db.execute('ALTER TABLE hotels ADD COLUMN $col TEXT');
        }
      }
      for (final col in const ['star_rating', 'rooms_count', 'secondary_color_value']) {
        if (!await hasColumn('hotels', col)) {
          await db.execute('ALTER TABLE hotels ADD COLUMN $col INTEGER');
        }
      }
      await db.execute(
        'CREATE TABLE IF NOT EXISTS hotel_audit_log (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, hotel_name TEXT NOT NULL, action TEXT NOT NULL, performed_by TEXT NOT NULL, details TEXT, created_at TEXT NOT NULL)',
      );
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

      await db.execute('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL UNIQUE, full_name TEXT NOT NULL, password TEXT NOT NULL, role_id TEXT, is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)');
      await db.execute('CREATE TABLE IF NOT EXISTS permission_groups (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, permissions_json TEXT NOT NULL DEFAULT "[]", created_at TEXT NOT NULL)');
      await _seedDefaultUsers(db);

      if (!await hasColumn('invoices', 'expense_category')) {
        await db.execute('ALTER TABLE invoices ADD COLUMN expense_category TEXT');
      }
      if (!await hasColumn('suppliers', 'notes')) {
        await db.execute('ALTER TABLE suppliers ADD COLUMN notes TEXT');
      }
      if (!await hasColumn('suppliers', 'default_expense_category')) {
        await db.execute('ALTER TABLE suppliers ADD COLUMN default_expense_category TEXT');
      }
      if (!await hasColumn('invoices', 'payment_method')) {
        await db.execute('ALTER TABLE invoices ADD COLUMN payment_method TEXT');
      }
      if (!await hasColumn('invoices', 'related_hotel_id')) {
        await db.execute('ALTER TABLE invoices ADD COLUMN related_hotel_id INTEGER');
      }
      await db.execute('CREATE TABLE IF NOT EXISTS supplier_debts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, supplier_id INTEGER NOT NULL, invoice_id INTEGER NOT NULL UNIQUE, amount REAL NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE, FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE)');
      await db.execute('CREATE TABLE IF NOT EXISTS supplier_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, supplier_id INTEGER NOT NULL, amount REAL NOT NULL, method TEXT, date TEXT NOT NULL, notes TEXT, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE)');
      await db.execute('CREATE TABLE IF NOT EXISTS invoice_attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, file_path TEXT NOT NULL, file_type TEXT NOT NULL, file_name TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
      await db.execute('CREATE TABLE IF NOT EXISTS invoice_audit_log (id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, username TEXT NOT NULL, operation_type TEXT NOT NULL, changed_fields TEXT, occurred_at TEXT NOT NULL)');

      if (!await hasColumn('expense_categories', 'short_code')) {
        await db.execute('ALTER TABLE expense_categories ADD COLUMN short_code TEXT');
      }
      if (!await hasColumn('expense_categories', 'is_default')) {
        await db.execute('ALTER TABLE expense_categories ADD COLUMN is_default INTEGER NOT NULL DEFAULT 0');
      }
      await _unifyExpenseCategories(db);

      await db.execute('CREATE TABLE IF NOT EXISTS document_categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, color_value INTEGER NOT NULL, created_at TEXT NOT NULL)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_categories_name ON document_categories(name)');
      await db.execute('CREATE TABLE IF NOT EXISTS document_types (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT, category_id INTEGER NOT NULL, is_mandatory INTEGER NOT NULL DEFAULT 0, requires_renewal INTEGER NOT NULL DEFAULT 0, scope TEXT NOT NULL DEFAULT "all", is_active INTEGER NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, lifecycle TEXT NOT NULL DEFAULT "permanent", FOREIGN KEY (category_id) REFERENCES document_categories (id))');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_types_name ON document_types(name)');
      await db.execute('CREATE TABLE IF NOT EXISTS document_type_hotels (id INTEGER PRIMARY KEY AUTOINCREMENT, document_type_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, FOREIGN KEY (document_type_id) REFERENCES document_types (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_type_hotels ON document_type_hotels(document_type_id, hotel_id)');
      await db.execute('CREATE TABLE IF NOT EXISTS document_attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, file_path TEXT NOT NULL, file_type TEXT NOT NULL, file_name TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
      if (!await hasColumn('documents', 'document_type_id')) {
        await db.execute('ALTER TABLE documents ADD COLUMN document_type_id INTEGER');
      }
      if (!await hasColumn('documents', 'document_number')) {
        await db.execute('ALTER TABLE documents ADD COLUMN document_number TEXT');
      }
      if (!await hasColumn('documents', 'issue_date')) {
        await db.execute('ALTER TABLE documents ADD COLUMN issue_date TEXT');
      }
      if (!await hasColumn('documents', 'issuing_authority')) {
        await db.execute('ALTER TABLE documents ADD COLUMN issuing_authority TEXT');
      }
      if (!await hasColumn('documents', 'notes')) {
        await db.execute('ALTER TABLE documents ADD COLUMN notes TEXT');
      }
      if (!await hasColumn('documents', 'owner_type')) {
        await db.execute('ALTER TABLE documents ADD COLUMN owner_type TEXT NOT NULL DEFAULT "hotel"');
      }
      if (!await hasColumn('documents', 'owner_id')) {
        await db.execute('ALTER TABLE documents ADD COLUMN owner_id INTEGER');
      }
      await db.execute('UPDATE documents SET owner_id = hotel_id WHERE owner_id IS NULL');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_owner ON documents(owner_type, owner_id)');
      if (!await hasColumn('document_types', 'lifecycle')) {
        await db.execute('ALTER TABLE document_types ADD COLUMN lifecycle TEXT NOT NULL DEFAULT "permanent"');
      }
      if (!await hasColumn('documents', 'hotel_scope')) {
        await db.execute('ALTER TABLE documents ADD COLUMN hotel_scope TEXT NOT NULL DEFAULT "single"');
      }
      await db.execute('CREATE TABLE IF NOT EXISTS document_hotels (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_hotels ON document_hotels(document_id, hotel_id)');
      await db.execute('CREATE TABLE IF NOT EXISTS document_folder_links (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL, document_type_id INTEGER NOT NULL, FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE, FOREIGN KEY (document_type_id) REFERENCES document_types (id) ON DELETE CASCADE)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_folder_links ON document_folder_links(document_id, document_type_id)');
      await _seedGlobalDocumentCategories(db);
      await _provisionDocumentTypesForAllHotels(db);
      await _migrateEmployeeDocuments(db);
      await _migratePermanentFolderLinks(db);

      if (!await hasColumn('pending_expenses', 'supplier_id')) {
        await db.execute('ALTER TABLE pending_expenses ADD COLUMN supplier_id INTEGER');
      }
      if (!await hasColumn('pending_expenses', 'due_date')) {
        await db.execute('ALTER TABLE pending_expenses ADD COLUMN due_date TEXT');
      }
      if (!await hasColumn('pending_expenses', 'funding_source_hotel_id')) {
        await db.execute('ALTER TABLE pending_expenses ADD COLUMN funding_source_hotel_id INTEGER');
      }
      await db.execute(
        'CREATE TABLE IF NOT EXISTS pending_expense_debts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, supplier_id INTEGER NOT NULL, pending_expense_id INTEGER NOT NULL UNIQUE, amount REAL NOT NULL, statement TEXT NOT NULL, due_date TEXT, status TEXT NOT NULL DEFAULT "غير مسدد", created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (supplier_id) REFERENCES suppliers (id), FOREIGN KEY (pending_expense_id) REFERENCES pending_expenses (id) ON DELETE CASCADE)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS pending_expense_attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, pending_expense_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, file_path TEXT NOT NULL, file_type TEXT NOT NULL, file_name TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (pending_expense_id) REFERENCES pending_expenses (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS financial_report_items (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, type TEXT NOT NULL, default_funding_source TEXT, is_visible INTEGER NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)',
      );
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_financial_report_items_name_type ON financial_report_items(name, type)');

      if (!await hasColumn('deposited_funds', 'posted_at')) {
        await db.execute('ALTER TABLE deposited_funds ADD COLUMN posted_at TEXT');
      }
      if (!await hasColumn('deposited_funds', 'posted_by')) {
        await db.execute('ALTER TABLE deposited_funds ADD COLUMN posted_by TEXT');
      }

      await db.execute(
        'CREATE TABLE IF NOT EXISTS shared_expense_groups (id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, category_id INTEGER NOT NULL, total_amount REAL NOT NULL, payment_method TEXT NOT NULL, funding_hotel_id INTEGER NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (category_id) REFERENCES expense_categories (id), FOREIGN KEY (funding_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS shared_expense_shares (id INTEGER PRIMARY KEY AUTOINCREMENT, shared_expense_group_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, FOREIGN KEY (shared_expense_group_id) REFERENCES shared_expense_groups (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)',
      );

      await db.execute(
        'CREATE TABLE IF NOT EXISTS advance_withdrawals (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, statement TEXT NOT NULL, method TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS inter_entity_transfers (id INTEGER PRIMARY KEY AUTOINCREMENT, from_hotel_id INTEGER NOT NULL, to_hotel_id INTEGER NOT NULL, amount REAL NOT NULL, statement TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (from_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (to_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)',
      );
    } catch (_) {
      // لا نمنع فتح قاعدة البيانات إن تعذّر أحد فحوصات الصيانة — التطبيق يبقى قابلاً للعمل
      // بالحد الأدنى، وتُعاد المحاولة تلقائياً عند فتح التطبيق مرة أخرى.
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS hotels (id INTEGER PRIMARY KEY AUTOINCREMENT, arabic_name TEXT NOT NULL, english_name TEXT NOT NULL, city TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1, has_parking INTEGER NOT NULL DEFAULT 0, identity_color_value INTEGER, archived_at TEXT, archived_by TEXT, status TEXT NOT NULL DEFAULT \'active\', archive_reason TEXT, hotel_code TEXT, description TEXT, country TEXT, district TEXT, address TEXT, maps_link TEXT, phone TEXT, mobile TEXT, whatsapp TEXT, email TEXT, website TEXT, star_rating INTEGER, rooms_count INTEGER, opening_date TEXT, notes TEXT, secondary_color_value INTEGER, logo_path TEXT, cover_image_path TEXT, currency TEXT, language TEXT, time_zone TEXT, date_format TEXT, time_format TEXT)');
    // سجل تدقيق الفنادق — بلا FOREIGN KEY عمداً (يبقى موجوداً حتى بعد حذف الفندق نهائياً).
    await db.execute('CREATE TABLE IF NOT EXISTS hotel_audit_log (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, hotel_name TEXT NOT NULL, action TEXT NOT NULL, performed_by TEXT NOT NULL, details TEXT, created_at TEXT NOT NULL)');
    // محرك المستندات الموحّد: كل مستند صف واحد فقط، بمرجع مالك متعدد الأشكال
    // (owner_type/owner_id) — 'hotel' (owner_id=hotel_id نفسه)، 'employee'، ومستقبلاً
    // 'supplier'/'contract'/... بلا أي تعديل معماري، فقط قيمة owner_type جديدة.
    await db.execute('CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, name TEXT NOT NULL, expiry_date TEXT NOT NULL, created_at TEXT NOT NULL, document_type_id INTEGER, document_number TEXT, issue_date TEXT, issuing_authority TEXT, notes TEXT, owner_type TEXT NOT NULL DEFAULT "hotel", owner_id INTEGER, hotel_scope TEXT NOT NULL DEFAULT "single", FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_owner ON documents(owner_type, owner_id)');
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
    // موحّدة على مستوى التطبيق بالكامل (hotel_id يبقى دوماً NULL) — مصدر الحقيقة الوحيد
    // لتصنيفات المصروفات، يُقرأ منه: الفواتير الضريبية، المصروفات المعلقة، مركز التحليل، المركز المالي، التقارير.
    await db.execute('CREATE TABLE IF NOT EXISTS expense_categories (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, name TEXT NOT NULL, short_code TEXT, usage_count INTEGER NOT NULL DEFAULT 0, is_pinned INTEGER NOT NULL DEFAULT 0, is_basic INTEGER NOT NULL DEFAULT 0, is_visible INTEGER NOT NULL DEFAULT 1, is_default INTEGER NOT NULL DEFAULT 0, icon_code INTEGER NOT NULL, color_value INTEGER NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_expense_categories_name ON expense_categories(name)');
    await db.execute('CREATE TABLE IF NOT EXISTS pending_expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, payment_method TEXT NOT NULL, category_id INTEGER NOT NULL, statement TEXT NOT NULL, notes TEXT, date TEXT NOT NULL, time TEXT NOT NULL, is_transferred INTEGER NOT NULL DEFAULT 0, amount_source TEXT NOT NULL DEFAULT "خارج النظام", created_at TEXT NOT NULL, supplier_id INTEGER, due_date TEXT, funding_source_hotel_id INTEGER, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (category_id) REFERENCES expense_categories (id) ON DELETE CASCADE)');
    // دين على المنشأة لمورد ناتج عن مصروف معلق بمصدر تمويل "آجل (دين)" — راجع
    // PendingExpenseDebt. مستقل عن supplier_debts (فواتير "شراء آجل" فقط)، وكلاهما
    // يُجمَّعان في "الذمم الدائنة" بمركز التحليل المالي (SupplierRepository.getAccountsPayableTotal).
    await db.execute('CREATE TABLE IF NOT EXISTS pending_expense_debts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, supplier_id INTEGER NOT NULL, pending_expense_id INTEGER NOT NULL UNIQUE, amount REAL NOT NULL, statement TEXT NOT NULL, due_date TEXT, status TEXT NOT NULL DEFAULT "غير مسدد", created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (supplier_id) REFERENCES suppliers (id), FOREIGN KEY (pending_expense_id) REFERENCES pending_expenses (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS pending_expense_attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, pending_expense_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, file_path TEXT NOT NULL, file_type TEXT NOT NULL, file_name TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (pending_expense_id) REFERENCES pending_expenses (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    // "المصروف المشترك": مصروف واحد تدفعه منشأة (funding_hotel_id) بالكامل، ويُوزَّع
    // على عدة منشآت مشارِكة عبر shared_expense_shares — القيود المحاسبية تُنفَّذ فوراً
    // عند الحفظ عبر FinancialEngine.recordSharedExpense، وهذان الجدولان للتتبع/العرض فقط.
    await db.execute('CREATE TABLE IF NOT EXISTS shared_expense_groups (id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, category_id INTEGER NOT NULL, total_amount REAL NOT NULL, payment_method TEXT NOT NULL, funding_hotel_id INTEGER NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (category_id) REFERENCES expense_categories (id), FOREIGN KEY (funding_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS shared_expense_shares (id INTEGER PRIMARY KEY AUTOINCREMENT, shared_expense_group_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, FOREIGN KEY (shared_expense_group_id) REFERENCES shared_expense_groups (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    // "السلفة": سحب فوري من نقد/شبكة الفندق لصالح المالك، ليست مصروفاً — القيد
    // المحاسبي (خصم فوري + ذمة owner_debt على المالك) عبر FinancialEngine.recordOwnerDrawing
    // مباشرة عند الحفظ، هذا الجدول للتتبع/العرض فقط (نفس شكل personal_withdrawals تماماً،
    // لكنه جدول مستقل لأن الاتجاه المحاسبي مختلف تماماً — راجع تعليق recordOwnerDrawing).
    await db.execute('CREATE TABLE IF NOT EXISTS advance_withdrawals (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, statement TEXT NOT NULL, method TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    // "التحويل بين المنشآت": تحويل مباشر لمبلغ بين فندقين بلا مصروف مرتبط —
    // جدول تتبّع/عرض فقط، القيد المحاسبي الفعلي عبر FinancialEngine.recordTransaction
    // (آلية entity_/receivable_entity نفسها المستخدمة أصلاً للمصروف المموَّل من فندق آخر).
    await db.execute('CREATE TABLE IF NOT EXISTS inter_entity_transfers (id INTEGER PRIMARY KEY AUTOINCREMENT, from_hotel_id INTEGER NOT NULL, to_hotel_id INTEGER NOT NULL, amount REAL NOT NULL, statement TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (from_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (to_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    // كتالوج بنود التقرير المالي اليومي الدائمة (إيراد/مصروف) — راجع
    // FinancialReportItemRepository. لا تظهر تلقائياً في الشاشة، فقط عبر
    // منتقي "إضافة بند" — التقارير المحفوظة سابقاً تحتفظ بنسخة كاملة داخل
    // details_json فلا ترتبط بهذا الجدول عبر FK إطلاقاً.
    await db.execute('CREATE TABLE IF NOT EXISTS financial_report_items (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, type TEXT NOT NULL, default_funding_source TEXT, is_visible INTEGER NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_financial_report_items_name_type ON financial_report_items(name, type)');
    await db.execute('CREATE TABLE IF NOT EXISTS deposited_funds (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, report_id INTEGER, date TEXT NOT NULL, cash_amount REAL NOT NULL, network_amount REAL NOT NULL, cash_status TEXT NOT NULL DEFAULT "pending", network_status TEXT NOT NULL DEFAULT "pending", is_archived INTEGER NOT NULL DEFAULT 0, posted_at TEXT, posted_by TEXT, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (report_id) REFERENCES financial_reports (id) ON DELETE SET NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS settlement_accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, name TEXT NOT NULL, type TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS settlements (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, account_id INTEGER, creditor_hotel_id INTEGER, debtor_hotel_id INTEGER, amount REAL NOT NULL, date TEXT NOT NULL, description TEXT NOT NULL, attachments_json TEXT, status TEXT NOT NULL DEFAULT "open", total_paid REAL NOT NULL DEFAULT 0, direction TEXT, created_at TEXT NOT NULL, FOREIGN KEY (account_id) REFERENCES settlement_accounts (id) ON DELETE CASCADE, FOREIGN KEY (creditor_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (debtor_hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS settlement_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, settlement_id INTEGER NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL, notes TEXT, amount_source TEXT NOT NULL DEFAULT "خارج النظام", FOREIGN KEY (settlement_id) REFERENCES settlements (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS invoices (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, invoice_number TEXT NOT NULL, date TEXT NOT NULL, company_name TEXT NOT NULL, tax_number TEXT NOT NULL, amount_before_tax REAL NOT NULL, vat REAL NOT NULL, total_amount REAL NOT NULL, facility_name TEXT NOT NULL, amount_source TEXT NOT NULL DEFAULT "خارج النظام", expense_category TEXT, payment_method TEXT, related_hotel_id INTEGER, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS suppliers (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, official_name TEXT NOT NULL, short_name TEXT NOT NULL, tax_number TEXT NOT NULL, notes TEXT, default_expense_category TEXT, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS contracts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER, name TEXT NOT NULL, contractor_name TEXT NOT NULL, start_date TEXT NOT NULL, duration TEXT NOT NULL, end_date TEXT NOT NULL, total_value REAL NOT NULL, payment_method TEXT NOT NULL, status TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS contract_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, contract_id INTEGER NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL, status TEXT NOT NULL, amount_source TEXT NOT NULL DEFAULT "خارج النظام", FOREIGN KEY (contract_id) REFERENCES contracts (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS vault_balances (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, UNIQUE(hotel_id, type))');
    await db.execute('CREATE TABLE IF NOT EXISTS vault_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, balance_before REAL NOT NULL, balance_after REAL NOT NULL, reference TEXT, notes TEXT, source TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS personal_withdrawals (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, statement TEXT NOT NULL, method TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS entity_loans (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, amount REAL NOT NULL, statement TEXT NOT NULL, source TEXT NOT NULL, date TEXT NOT NULL, time TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL UNIQUE, full_name TEXT NOT NULL, password TEXT NOT NULL, role_id TEXT, is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS permission_groups (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, permissions_json TEXT NOT NULL DEFAULT "[]", created_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS supplier_debts (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, supplier_id INTEGER NOT NULL, invoice_id INTEGER NOT NULL UNIQUE, amount REAL NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE, FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS supplier_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_id INTEGER NOT NULL, supplier_id INTEGER NOT NULL, amount REAL NOT NULL, method TEXT, date TEXT NOT NULL, notes TEXT, created_at TEXT NOT NULL, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE, FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS invoice_attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, file_path TEXT NOT NULL, file_type TEXT NOT NULL, file_name TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS invoice_audit_log (id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, username TEXT NOT NULL, operation_type TEXT NOT NULL, changed_fields TEXT, occurred_at TEXT NOT NULL)');
    // موحّدة على مستوى التطبيق بالكامل — مصدر الحقيقة الوحيد لأنواع المستندات المرجعية
    // وفئاتها، تُزوَّد منه تلقائياً كل الفنادق (راجع _provisionDocumentTypesForAllHotels).
    await db.execute('CREATE TABLE IF NOT EXISTS document_categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, color_value INTEGER NOT NULL, created_at TEXT NOT NULL)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_categories_name ON document_categories(name)');
    await db.execute('CREATE TABLE IF NOT EXISTS document_types (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT, category_id INTEGER NOT NULL, is_mandatory INTEGER NOT NULL DEFAULT 0, requires_renewal INTEGER NOT NULL DEFAULT 0, scope TEXT NOT NULL DEFAULT "all", is_active INTEGER NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, lifecycle TEXT NOT NULL DEFAULT "permanent", FOREIGN KEY (category_id) REFERENCES document_categories (id))');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_types_name ON document_types(name)');
    await db.execute('CREATE TABLE IF NOT EXISTS document_type_hotels (id INTEGER PRIMARY KEY AUTOINCREMENT, document_type_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, FOREIGN KEY (document_type_id) REFERENCES document_types (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_type_hotels ON document_type_hotels(document_type_id, hotel_id)');
    await db.execute('CREATE TABLE IF NOT EXISTS document_attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, file_path TEXT NOT NULL, file_type TEXT NOT NULL, file_name TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    // نطاق فنادق مستند واحد عندما hotel_scope='specific' (أكثر من فندق) — راجع
    // documents.hotel_scope: 'single' (hotel_id وحده كما هو معتاد)، 'all'
    // (كل الفنادق، يُحسَب ديناميكياً بلا صفوف هنا)، 'specific' (هذا الجدول).
    await db.execute('CREATE TABLE IF NOT EXISTS document_hotels (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL, hotel_id INTEGER NOT NULL, FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE, FOREIGN KEY (hotel_id) REFERENCES hotels (id) ON DELETE CASCADE)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_hotels ON document_hotels(document_id, hotel_id)');
    // مراجع "المستند يظهر داخل مجلد" (نوع مرجعي) — علاقة متعددة لأكثر من مجلد
    // لنفس المستند بلا أي نسخ للملف أو للسجل (مبدأ "References" في قسم المستندات).
    await db.execute('CREATE TABLE IF NOT EXISTS document_folder_links (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL, document_type_id INTEGER NOT NULL, FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE, FOREIGN KEY (document_type_id) REFERENCES document_types (id) ON DELETE CASCADE)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_document_folder_links ON document_folder_links(document_id, document_type_id)');
  }

  /// يزرع نفس المستخدمين الثلاثة الافتراضيين الذين كانوا مُدرَجين سابقاً كقائمة
  /// ثابتة في UserRepository — الآن كصفوف حقيقية في جدول users. لا يُدرج شيئاً
  /// إن كان الجدول يحتوي بيانات بالفعل (لتفادي التكرار عند كل فتح للتطبيق).
  Future<void> _seedDefaultUsers(Database db) async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;
    if (count > 0) return;
    final now = DateTime.now().toIso8601String();
    final defaults = [
      {'username': 'admin', 'full_name': 'مدير النظام', 'password': '123456', 'role_id': 'admin'},
      {'username': 'manager', 'full_name': 'مدير الفندق', 'password': '123456', 'role_id': 'manager'},
      {'username': 'employee', 'full_name': 'موظف', 'password': '123456', 'role_id': 'employee'},
    ];
    for (final u in defaults) {
      await db.insert('users', {...u, 'is_active': 1, 'created_at': now}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _initializeData(Database db) async {
    final hotels = await db.query('hotels');
    for (var hotel in hotels) {
      final hId = hotel['id'] as int;
      await _initFinancialAccountsForHotel(db, hId);
    }
    await _seedGlobalExpenseCategories(db);
    await _seedGlobalDocumentCategories(db);
    await _provisionDocumentTypesForAllHotels(db);
    await _seedDefaultUsers(db);
  }

  Future<void> _initFinancialAccountsForHotel(Database db, int hId) async {
    await db.insert('financial_accounts', {'hotel_id': hId, 'name': 'الخزنة (نقد)', 'type': 'asset', 'category': 'cash', 'balance': 0.0});
    await db.insert('financial_accounts', {'hotel_id': hId, 'name': 'الحساب البنكي', 'type': 'asset', 'category': 'bank', 'balance': 0.0});
    await db.insert('financial_accounts', {'hotel_id': hId, 'name': 'الحساب الشخصي (المالك)', 'type': 'liability', 'category': 'personal', 'balance': 0.0});
    await db.insert('financial_accounts', {'hotel_id': hId, 'name': 'مستحقات من منشآت أخرى', 'type': 'asset', 'category': 'receivable_entity', 'balance': 0.0});
    await db.insert('financial_accounts', {'hotel_id': hId, 'name': 'ديون لمنشآت أخرى', 'type': 'liability', 'category': 'entity', 'balance': 0.0});
  }

  /// يزرع 14 تصنيف مصروف افتراضي على مستوى التطبيق بالكامل (hotel_id = NULL) وليس
  /// لكل فندق كما كان سابقاً. آمنة للتشغيل المتكرر ولإعادة الترحيل: تعتمد على فهرس
  /// UNIQUE(name) (عبر ConflictAlgorithm.ignore) بدل عدّ الصفوف — حتى تُضيف فقط
  /// الأسماء الناقصة فعلياً بعد ترحيل تصنيفات قديمة كانت موجودة بأسماء أخرى.
  Future<void> _seedGlobalExpenseCategories(Database db) async {
    final cats = [
      {'n': 'مشتريات عامة', 'i': 0xe59c, 'c': 0xFF00BCD4},
      {'n': 'صيانة', 'i': 0xe1bd, 'c': 0xFFFF9800},
      {'n': 'رسوم حكومية', 'i': 0xe69a, 'c': 0xFF9C27B0},
      {'n': 'منظفات', 'i': 0xe0bc, 'c': 0xFF009688},
      {'n': 'عمولات', 'i': 0xe55b, 'c': 0xFF673AB7},
      {'n': 'مكتب العمل', 'i': 0xe8b8, 'c': 0xFF455A64},
      {'n': 'الاتصالات', 'i': 0xe0cd, 'c': 0xFF3F51B5},
      {'n': 'مخالفات', 'i': 0xe3f1, 'c': 0xFF212121},
      {'n': 'أثاث الفندق', 'i': 0xe190, 'c': 0xFF607D8B},
      {'n': 'كهرباء', 'i': 0xe098, 'c': 0xFFFFEB3B},
      {'n': 'مياه', 'i': 0xe6e4, 'c': 0xFF2196F3},
      {'n': 'رواتب', 'i': 0xe4f4, 'c': 0xFF4CAF50},
      {'n': 'إيجار', 'i': 0xe317, 'c': 0xFFF44336},
      {'n': 'أخرى', 'i': 0xe570, 'c': 0xFF795548},
    ];
    final now = DateTime.now().toIso8601String();
    var order = 0;
    for (var cat in cats) {
      await db.insert('expense_categories', {
        'hotel_id': null, 'name': cat['n'], 'is_basic': 1, 'sort_order': order,
        'icon_code': cat['i'], 'color_value': cat['c'], 'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      order++;
    }
  }

  /// يوحّد جدول expense_categories ليصبح مصدراً وحيداً على مستوى التطبيق بدل نظام
  /// كان لكل فندق نسخته الخاصة. يدمج أي صفوف مكررة بنفس الاسم (يُعاد توجيه
  /// pending_expenses.category_id إلى الصف الموحَّد أولاً — قبل حذف الصف المكرر —
  /// لتفادي فقدان بيانات بسبب ON DELETE CASCADE)، ثم يجعل كل الصفوف المتبقية عامة
  /// (hotel_id = NULL)، ثم يضمن فرادة الاسم عبر فهرس UNIQUE، ثم يضيف أي تصنيف افتراضي
  /// ناقص من القائمة الأساسية. آمنة للتشغيل المتكرر عند كل فتح لقاعدة البيانات.
  Future<void> _unifyExpenseCategories(Database db) async {
    final anyScoped = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM expense_categories WHERE hotel_id IS NOT NULL')) ?? 0;
    if (anyScoped > 0) {
      await db.transaction((txn) async {
        final rows = await txn.query('expense_categories', orderBy: 'id ASC');
        final Map<String, int> canonicalIdByName = {};
        for (var row in rows) {
          final name = row['name'] as String;
          final id = row['id'] as int;
          final canonicalId = canonicalIdByName[name];
          if (canonicalId == null) {
            canonicalIdByName[name] = id;
            continue;
          }
          await txn.update('pending_expenses', {'category_id': canonicalId}, where: 'category_id = ?', whereArgs: [id]);
          await txn.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
        }
        await txn.update('expense_categories', {'hotel_id': null});
      });
    }
    try {
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_expense_categories_name ON expense_categories(name)');
    } catch (_) {}
    await _seedGlobalExpenseCategories(db);
  }

  /// يزرع 5 فئات افتراضية لأنواع المستندات المرجعية — مرة واحدة فقط، آمنة
  /// للتشغيل المتكرر عبر فهرس UNIQUE(name) و ConflictAlgorithm.ignore.
  Future<void> _seedGlobalDocumentCategories(Database db) async {
    final cats = [
      {'n': 'حكومي', 'c': 0xFF9C27B0},
      {'n': 'مالي', 'c': 0xFF4CAF50},
      {'n': 'قانوني', 'c': 0xFF3F51B5},
      {'n': 'تشغيلي', 'c': 0xFFFF9800},
      {'n': 'عقود', 'c': 0xFF607D8B},
    ];
    final now = DateTime.now().toIso8601String();
    for (var cat in cats) {
      await db.insert('document_categories', {
        'name': cat['n'], 'color_value': cat['c'], 'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// يزوّد فندقاً واحداً تلقائياً بكل أنواع المستندات المرجعية المطابقة (المفعَّلة،
  /// وإما "لكل الفنادق" أو مخصَّصة لهذا الفندق تحديداً) — يُدرج صفاً فارغاً في
  /// documents لكل نوع لا يملك الفندق صفاً به بعد (expiry_date='' كبديل آمن عن
  /// NULL طالما العمود NOT NULL؛ DateTime.tryParse('') تُعيد null بأمان في كل
  /// أماكن القراءة الحالية). آمنة للتشغيل المتكرر: لا تكرر صفاً موجوداً فعلاً.
  Future<void> _provisionDocumentTypesForHotel(Database db, int hotelId) async {
    final types = await db.rawQuery(
      'SELECT dt.* FROM document_types dt WHERE dt.is_active = 1 AND (dt.scope = "all" OR EXISTS (SELECT 1 FROM document_type_hotels dth WHERE dth.document_type_id = dt.id AND dth.hotel_id = ?))',
      [hotelId],
    );
    final now = DateTime.now().toIso8601String();
    for (var type in types) {
      final typeId = type['id'] as int;
      final exists = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM documents WHERE hotel_id = ? AND document_type_id = ?',
        [hotelId, typeId],
      )) ?? 0;
      if (exists > 0) continue;
      await db.insert('documents', {
        'hotel_id': hotelId,
        'document_type_id': typeId,
        'name': type['name'],
        'expiry_date': '',
        'created_at': now,
        'owner_type': 'hotel',
        'owner_id': hotelId,
      });
    }
  }

  /// يرحّل جدول employee_documents القديم (منفصل، بلا مرفقات) إلى جدول
  /// documents الموحّد (owner_type='employee') مرة واحدة فقط — دون فقدان أي
  /// بيانات: النوع القديم (type) يُدمَج داخل notes، وتاريخ الانتهاء الفارغ
  /// يُخزَّن كنص فارغ (نفس اصطلاح باقي الجدول). لا يُحذف الجدول القديم (عرف
  /// "إضافة فقط" في هذا المشروع)، لكنه لم يعد يُستخدم من أي كود Dart بعد الآن.
  Future<void> _migrateEmployeeDocuments(Database db) async {
    final alreadyMigrated = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM documents WHERE owner_type = 'employee'")) ?? 0;
    if (alreadyMigrated > 0) return;
    final rows = await db.rawQuery(
      'SELECT ed.*, e.hotel_id as emp_hotel_id FROM employee_documents ed JOIN employees e ON e.id = ed.employee_id',
    );
    for (var row in rows) {
      final oldType = (row['type'] as String?) ?? '';
      final oldNotes = row['notes'] as String?;
      final combinedNotes = oldType.isEmpty
          ? oldNotes
          : 'النوع السابق: $oldType${(oldNotes != null && oldNotes.isNotEmpty) ? '\n$oldNotes' : ''}';
      await db.insert('documents', {
        'hotel_id': row['emp_hotel_id'],
        'owner_type': 'employee',
        'owner_id': row['employee_id'],
        'document_type_id': null,
        'name': row['name'],
        'expiry_date': row['expiry_date'] ?? '',
        'notes': combinedNotes,
        'created_at': row['created_at'],
      });
    }
  }

  /// يربط كل مستند فندق (owner_type='hotel') مرتبط بنوع مرجعي بمجلده عبر
  /// document_folder_links مرة واحدة فقط — حتى تبقى مستندات "المستندات
  /// الدائمة" التي أُنشئت قبل إضافة نظام المراجع (References) ظاهرة داخل
  /// مجلداتها دون فقدان، ودون إنشاء أي نسخة إضافية (مجرد صف مرجع).
  Future<void> _migratePermanentFolderLinks(Database db) async {
    final alreadyMigrated = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM document_folder_links')) ?? 0;
    if (alreadyMigrated > 0) return;
    final rows = await db.query('documents', where: 'document_type_id IS NOT NULL');
    for (var row in rows) {
      await db.insert(
        'document_folder_links',
        {'document_id': row['id'], 'document_type_id': row['document_type_id']},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// يزوّد كل الفنادق الحالية دفعة واحدة — يُستدعى عند التثبيت الجديد وعند كل
  /// فتح لقاعدة البيانات (شبكة أمان)، وأيضاً من DocumentTypeRepository فور
  /// تفعيل/حفظ نوع مستند حتى ينتشر فوراً دون انتظار إنشاء فندق جديد.
  Future<void> _provisionDocumentTypesForAllHotels(Database db) async {
    final hotels = await db.query('hotels');
    for (var hotel in hotels) {
      await _provisionDocumentTypesForHotel(db, hotel['id'] as int);
    }
  }

  /// غلاف عام يستدعيه DocumentTypeRepository فور حفظ/تفعيل نوع مستند، لينشره
  /// فوراً على كل الفنادق المطابقة دون انتظار إنشاء فندق جديد.
  Future<void> provisionDocumentTypesAcrossHotels() async {
    final db = await database;
    await _provisionDocumentTypesForAllHotels(db);
  }

  // --- CRUD ---
  /// [active] null = كل الفنادق (مؤرشَفة وغير مؤرشَفة معاً — للاستخدامات التي
  /// تحتاج تحليل اسم فندق قديم حتى لو أُرشِف لاحقاً)، true = غير مؤرشَفة فقط،
  /// false = مؤرشَفة فقط (سلة المحذوفات).
  Future<List<Map<String, dynamic>>> getHotels({bool? active}) async {
    final db = await database;
    if (active == null) return await db.query('hotels');
    return await db.query('hotels', where: 'active = ?', whereArgs: [active ? 1 : 0]);
  }
  Future<int> insertHotel(Map<String, dynamic> data) async { final db = await database; final id = await db.insert('hotels', data); await _initFinancialAccountsForHotel(db, id); await _provisionDocumentTypesForHotel(db, id); return id; }
  Future<int> updateHotel(Map<String, dynamic> data, int id) async { final db = await database; return await db.update('hotels', data, where: 'id = ?', whereArgs: [id]); }

  /// أرشفة (بدل الحذف النهائي): تبقى كل البيانات المرتبطة كما هي تماماً،
  /// فقط active=0 وstatus='archived' معاً فيختفي الفندق من القائمة الرئيسية
  /// ويظهر في سلة المحذوفات.
  Future<int> archiveHotel(int id, {required String archivedBy, String? reason}) async {
    final db = await database;
    return await db.update(
      'hotels',
      {'active': 0, 'status': 'archived', 'archived_at': DateTime.now().toIso8601String(), 'archived_by': archivedBy, 'archive_reason': reason},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> restoreHotel(int id) async {
    final db = await database;
    return await db.update(
      'hotels',
      {'active': 1, 'status': 'active', 'archived_at': null, 'archived_by': null, 'archive_reason': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// حذف نهائي حقيقي — لا رجعة عنه، يحذف كل البيانات المرتبطة بالفندق عبر
  /// ON DELETE CASCADE. يُستخدم فقط من سلة المحذوفات بعد تأكيد صريح متعدد
  /// المراحل (راجع RecycleBinPage) — لا يُستدعى مباشرة من أي شاشة أخرى.
  Future<int> deleteHotel(int id) async { final db = await database; return await db.delete('hotels', where: 'id = ?', whereArgs: [id]); }

  // ---------------- سجل تدقيق الفنادق (hotel_audit_log) ----------------

  Future<int> insertHotelAuditLog(Map<String, dynamic> data) async { final db = await database; return await db.insert('hotel_audit_log', data); }

  /// [hotelId] null = سجل كل الفنادق معاً (للعرض العام)، وإلا سجل فندق واحد فقط.
  Future<List<Map<String, dynamic>>> getHotelAuditLog({int? hotelId}) async {
    final db = await database;
    if (hotelId == null) return await db.query('hotel_audit_log', orderBy: 'id DESC');
    return await db.query('hotel_audit_log', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'id DESC');
  }

  Future<int> insertFinancialReport(Map<String, dynamic> data) async { final db = await database; return await db.insert('financial_reports', data); }
  Future<List<Map<String, dynamic>>> getFinancialReports({required int hotelId}) async { final db = await database; return await db.query('financial_reports', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'date DESC'); }
  Future<List<Map<String, dynamic>>> getUnpostedReports(int hotelId) async { final db = await database; return await db.query('financial_reports', where: 'hotel_id = ? AND is_posted = 0', whereArgs: [hotelId], orderBy: 'date DESC'); }
  Future<Map<String, dynamic>?> getMainReportForDate(int hotelId, String date) async {
    final db = await database;
    final results = await db.query('financial_reports', where: 'hotel_id = ? AND date = ? AND report_type = "main"', whereArgs: [hotelId, date], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  /// قائمة تصنيفات المصروفات الموحدة على مستوى التطبيق بالكامل (لا فلترة بفندق).
  Future<List<Map<String, dynamic>>> getExpenseCategories({bool includeHidden = false}) async {
    final db = await database;
    return await db.query('expense_categories', where: includeHidden ? null : 'is_visible = 1', orderBy: 'is_pinned DESC, sort_order ASC');
  }
  Future<int> insertExpenseCategory(Map<String, dynamic> data) async { final db = await database; return await db.insert('expense_categories', data); }

  Future<List<Map<String, dynamic>>> getPendingExpenses({required int hotelId, bool? isTransferred}) async {
    final db = await database;
    String where = 'pe.hotel_id = ?'; List<dynamic> args = [hotelId];
    if (isTransferred != null) { where += ' AND pe.is_transferred = ?'; args.add(isTransferred ? 1 : 0); }
    return await db.rawQuery(
      'SELECT pe.*, ec.name as category_name, ec.icon_code, ec.color_value, s.official_name as supplier_name '
      'FROM pending_expenses pe JOIN expense_categories ec ON pe.category_id = ec.id '
      'LEFT JOIN suppliers s ON s.id = pe.supplier_id WHERE $where ORDER BY pe.date DESC, pe.time DESC',
      args,
    );
  }
  Future<int> insertPendingExpense(Map<String, dynamic> data) async { final db = await database; await db.execute('UPDATE expense_categories SET usage_count = usage_count + 1 WHERE id = ?', [data['category_id']]); return await db.insert('pending_expenses', data); }
  Future<void> transferPendingExpenses(List<int> ids) async { final db = await database; await db.transaction((txn) async { for (var id in ids) { await txn.update('pending_expenses', {'is_transferred': 1}, where: 'id = ?', whereArgs: [id]); } }); }
  /// إلغاء ترحيل مصروفات معلقة (عكس [transferPendingExpenses]) — تُستخدم عند
  /// "إلغاء ترحيل المصروف" من داخل التقرير اليومي، لإعادتها إلى المصروفات
  /// المعلقة القابلة للتعديل.
  Future<void> untransferExpenses(List<int> ids) async { final db = await database; await db.transaction((txn) async { for (var id in ids) { await txn.update('pending_expenses', {'is_transferred': 0}, where: 'id = ?', whereArgs: [id]); } }); }

  // ---------------- ديون المصروفات المعلقة الآجلة (pending_expense_debts) ----------------

  Future<Map<String, dynamic>?> getPendingExpenseDebtByPendingExpenseId(int pendingExpenseId) async {
    final db = await database;
    final rows = await db.query('pending_expense_debts', where: 'pending_expense_id = ?', whereArgs: [pendingExpenseId], limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }
  Future<int> insertPendingExpenseDebt(Map<String, dynamic> data) async { final db = await database; return await db.insert('pending_expense_debts', data); }
  Future<int> updatePendingExpenseDebt(int id, Map<String, dynamic> data) async { final db = await database; return await db.update('pending_expense_debts', data, where: 'id = ?', whereArgs: [id]); }
  Future<int> deletePendingExpenseDebtByPendingExpenseId(int pendingExpenseId) async { final db = await database; return await db.delete('pending_expense_debts', where: 'pending_expense_id = ?', whereArgs: [pendingExpenseId]); }

  /// إجمالي "الذمم الدائنة" (ديون على المنشأة) لكل فندق: مجموع مديونيات
  /// الفواتير الآجلة (supplier_debts) + مديونيات المصروفات المعلقة الآجلة
  /// (pending_expense_debts) لموردي هذا الفندق، ناقص ما سُدِّد فعلياً
  /// (supplier_payments) — لا شاشة سداد بعد فتبقى النتيجة عملياً مجموع الديون.
  Future<double> getAccountsPayableTotalForHotel(int hotelId) async {
    final db = await database;
    final res = await db.rawQuery(
      '''
      SELECT
        (SELECT COALESCE(SUM(sd.amount), 0) FROM supplier_debts sd JOIN suppliers s ON s.id = sd.supplier_id WHERE s.hotel_id = ?)
        + (SELECT COALESCE(SUM(ped.amount), 0) FROM pending_expense_debts ped WHERE ped.hotel_id = ? AND ped.status != 'مسدد')
        - (SELECT COALESCE(SUM(sp.amount), 0) FROM supplier_payments sp JOIN suppliers s2 ON s2.id = sp.supplier_id WHERE s2.hotel_id = ?)
        AS total
      ''',
      [hotelId, hotelId, hotelId],
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// كل الموردين الذين لديهم رصيد مديونية مستحق (> 0) لفندق معيّن — أساس
  /// شاشة "الذمم الدائنة" التفصيلية في المركز المالي.
  Future<List<Map<String, dynamic>>> getSuppliersWithOutstandingDebt(int hotelId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT s.id, s.official_name, s.short_name,
        (COALESCE((SELECT SUM(amount) FROM supplier_debts WHERE supplier_id = s.id), 0)
         + COALESCE((SELECT SUM(amount) FROM pending_expense_debts WHERE supplier_id = s.id AND status != 'مسدد'), 0)
         - COALESCE((SELECT SUM(amount) FROM supplier_payments WHERE supplier_id = s.id), 0)) AS balance
      FROM suppliers s
      WHERE s.hotel_id = ?
      HAVING balance > 0
      ORDER BY balance DESC
      ''',
      [hotelId],
    );
  }

  // ---------------- مرفقات المصروفات المعلقة (pending_expense_attachments) ----------------

  Future<int> insertPendingExpenseAttachment(Map<String, dynamic> data) async { final db = await database; return await db.insert('pending_expense_attachments', data); }
  Future<List<Map<String, dynamic>>> getPendingExpenseAttachments(int pendingExpenseId) async { final db = await database; return await db.query('pending_expense_attachments', where: 'pending_expense_id = ?', whereArgs: [pendingExpenseId], orderBy: 'created_at DESC'); }

  // ---------------- المصروف المشترك (shared_expense_groups/shared_expense_shares) ----------------

  Future<int> insertSharedExpenseGroup(Map<String, dynamic> data) async { final db = await database; return await db.insert('shared_expense_groups', data); }
  Future<int> insertSharedExpenseShare(Map<String, dynamic> data) async { final db = await database; return await db.insert('shared_expense_shares', data); }
  Future<List<Map<String, dynamic>>> getSharedExpenseSharesForHotelAndDate(int hotelId, String date) async {
    final db = await database;
    return await db.rawQuery(
      'SELECT s.*, g.description as group_description, g.total_amount as group_total_amount, g.payment_method as group_payment_method, '
      'g.funding_hotel_id as group_funding_hotel_id, g.date as group_date, h.arabic_name as funding_hotel_name '
      'FROM shared_expense_shares s '
      'JOIN shared_expense_groups g ON g.id = s.shared_expense_group_id '
      'JOIN hotels h ON h.id = g.funding_hotel_id '
      'WHERE s.hotel_id = ? AND g.date = ? ORDER BY g.created_at DESC',
      [hotelId, date],
    );
  }

  /// كل مجموعات المصروف المشترك التي مَوَّلتها منشأة معيّنة — لعرض قسم "المصروفات
  /// المشتركة" في شاشة العمليات المالية المعلقة (عرض/عدّاد فقط، بلا أي أثر محاسبي إضافي).
  Future<List<Map<String, dynamic>>> getSharedExpenseGroupsByFundingHotel(int hotelId) async {
    final db = await database;
    return await db.query('shared_expense_groups', where: 'funding_hotel_id = ?', whereArgs: [hotelId], orderBy: 'date DESC, time DESC');
  }

  // ---------------- السلفة (advance_withdrawals) ----------------

  Future<int> insertAdvanceWithdrawal(Map<String, dynamic> data) async { final db = await database; return await db.insert('advance_withdrawals', data); }
  Future<List<Map<String, dynamic>>> getAdvanceWithdrawals(int hotelId) async { final db = await database; return await db.query('advance_withdrawals', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'date DESC, time DESC'); }

  // ---------------- التحويل بين المنشآت (inter_entity_transfers) ----------------

  Future<int> insertInterEntityTransfer(Map<String, dynamic> data) async { final db = await database; return await db.insert('inter_entity_transfers', data); }
  Future<List<Map<String, dynamic>>> getInterEntityTransfers(int hotelId) async {
    final db = await database;
    return await db.query('inter_entity_transfers', where: 'from_hotel_id = ? OR to_hotel_id = ?', whereArgs: [hotelId, hotelId], orderBy: 'date DESC, time DESC');
  }

  // ---------------- كتالوج بنود التقرير المالي اليومي (financial_report_items) ----------------

  Future<List<Map<String, dynamic>>> getFinancialReportItems({String? type, bool includeHidden = false}) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (type != null) { where.add('type = ?'); args.add(type); }
    if (!includeHidden) where.add('is_visible = 1');
    return await db.query(
      'financial_report_items',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'sort_order ASC',
    );
  }
  Future<int> insertFinancialReportItem(Map<String, dynamic> data) async { final db = await database; return await db.insert('financial_report_items', data); }

  Future<List<Map<String, dynamic>>> getNotes(int hotelId) async { final db = await database; return await db.query('notes', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'created_at DESC'); }
  Future<int> insertNote(Map<String, dynamic> data) async { final db = await database; return await db.insert('notes', data); }

  Future<int> insertDocument(Map<String, dynamic> data) async { final db = await database; return await db.insert('documents', data); }

  // ---------------- أنواع المستندات المرجعية (Document Types) ----------------

  Future<List<Map<String, dynamic>>> getDocumentCategories() async { final db = await database; return await db.query('document_categories', orderBy: 'name ASC'); }
  Future<int> insertDocumentCategory(Map<String, dynamic> data) async { final db = await database; return await db.insert('document_categories', data); }

  Future<List<Map<String, dynamic>>> getDocumentTypes({bool includeInactive = true, String? lifecycle}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (!includeInactive) conditions.add('dt.is_active = 1');
    if (lifecycle != null) {
      conditions.add('dt.lifecycle = ?');
      args.add(lifecycle);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return await db.rawQuery(
      'SELECT dt.*, dc.name as category_name, dc.color_value as category_color FROM document_types dt JOIN document_categories dc ON dc.id = dt.category_id $where ORDER BY dt.sort_order ASC, dt.name ASC',
      args,
    );
  }

  Future<Map<String, dynamic>?> getDocumentTypeById(int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT dt.*, dc.name as category_name, dc.color_value as category_color FROM document_types dt JOIN document_categories dc ON dc.id = dt.category_id WHERE dt.id = ?',
      [id],
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> insertDocumentType(Map<String, dynamic> data) async { final db = await database; return await db.insert('document_types', data); }

  Future<List<int>> getDocumentTypeHotelIds(int documentTypeId) async {
    final db = await database;
    final rows = await db.query('document_type_hotels', where: 'document_type_id = ?', whereArgs: [documentTypeId]);
    return rows.map((r) => r['hotel_id'] as int).toList();
  }

  Future<void> setDocumentTypeHotels(int documentTypeId, List<int> hotelIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('document_type_hotels', where: 'document_type_id = ?', whereArgs: [documentTypeId]);
      for (var hId in hotelIds) {
        await txn.insert('document_type_hotels', {'document_type_id': documentTypeId, 'hotel_id': hId});
      }
    });
  }

  /// مستندات فندق واحد مع بيانات نوعها/فئتها الحيّة (JOIN) — الفرز حسب أولوية
  /// الحالة (منتهي أولاً... إلخ) يتم في طبقة الـ Repository لأنه يعتمد على
  /// التاريخ الحالي وليس عموداً ثابتاً في قاعدة البيانات.
  Future<List<Map<String, dynamic>>> getDocumentsForHotel(int hotelId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT d.*, dt.name as type_name, dt.description as type_description, dt.is_mandatory, dt.requires_renewal,
             dc.name as category_name, dc.color_value as category_color
      FROM documents d
      LEFT JOIN document_types dt ON dt.id = d.document_type_id
      LEFT JOIN document_categories dc ON dc.id = dt.category_id
      WHERE d.hotel_id = ?
      ''',
      [hotelId],
    );
  }

  /// مستندات مالك واحد بعينه (موظف/مورد/عقد/... حسب [ownerType]) — نفس بنية
  /// [getDocumentsForHotel] لكن مُصفَّاة بالمالك بدل الفندق بأكمله. هذا هو
  /// نقطة التوسع الوحيدة المطلوبة لربط أي كيان جديد بمحرك المستندات مستقبلاً:
  /// استدعاء هذه الدالة بقيمة owner_type جديدة، بلا أي تعديل معماري آخر.
  Future<List<Map<String, dynamic>>> getDocumentsForOwner(String ownerType, int ownerId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT d.*, dt.name as type_name, dt.description as type_description, dt.is_mandatory, dt.requires_renewal,
             dc.name as category_name, dc.color_value as category_color
      FROM documents d
      LEFT JOIN document_types dt ON dt.id = d.document_type_id
      LEFT JOIN document_categories dc ON dc.id = dt.category_id
      WHERE d.owner_type = ? AND d.owner_id = ?
      ''',
      [ownerType, ownerId],
    );
  }

  /// جملة WHERE تُطابق مستندات "تخص" مجموعة فنادق معيّنة مراعيةً نطاق كل
  /// مستند (hotel_scope: single/all/specific) — مصدر وحيد لهذا المنطق، تُستخدم
  /// من أي استعلام مستندات متعدد الفنادق (داخل مجلد، بحث، ...) حتى لا يتكرر.
  /// تضيف عناصرها إلى [args] مباشرة (استدعِها بعد إضافة أي شروط where سابقة).
  String _hotelScopeWhereClause(List<int> hotelIds, List<dynamic> args, {String alias = 'd'}) {
    final placeholders = List.filled(hotelIds.length, '?').join(',');
    args.addAll(hotelIds);
    args.addAll(hotelIds);
    return '''
      ($alias.hotel_scope = 'all'
       OR ($alias.hotel_scope = 'single' AND $alias.hotel_id IN ($placeholders))
       OR ($alias.hotel_scope = 'specific' AND EXISTS (SELECT 1 FROM document_hotels dh WHERE dh.document_id = $alias.id AND dh.hotel_id IN ($placeholders))))
    ''';
  }

  /// "داخل مجلد" — كل المستندات المرتبطة بنوع مرجعي (مجلد) عبر جدول المراجع
  /// document_folder_links (وليس عمود document_type_id المباشر فقط)، لأن
  /// مستنداً واحداً قد يظهر في أكثر من مجلد بلا أي نسخ. فلترة اختيارية
  /// بمجموعة فنادق (فارغة/null = بلا فلترة) تراعي نطاق كل مستند
  /// (hotel_scope: single/all/specific).
  Future<List<Map<String, dynamic>>> getDocumentsInFolder(int documentTypeId, {List<int>? hotelIds, String? ownerType, int? ownerId}) async {
    final db = await database;
    final where = <String>['dfl.document_type_id = ?'];
    final args = <dynamic>[documentTypeId];
    if (hotelIds != null && hotelIds.isNotEmpty) {
      where.add(_hotelScopeWhereClause(hotelIds, args));
    }
    if (ownerType != null) {
      where.add('d.owner_type = ?');
      args.add(ownerType);
    }
    if (ownerId != null) {
      where.add('d.owner_id = ?');
      args.add(ownerId);
    }
    return await db.rawQuery(
      '''
      SELECT d.*, dt.name as type_name, dt.description as type_description, dt.is_mandatory, dt.requires_renewal,
             dc.name as category_name, dc.color_value as category_color, h.arabic_name as hotel_name
      FROM documents d
      JOIN document_folder_links dfl ON dfl.document_id = d.id
      LEFT JOIN document_types dt ON dt.id = d.document_type_id
      LEFT JOIN document_categories dc ON dc.id = dt.category_id
      LEFT JOIN hotels h ON h.id = d.hotel_id
      WHERE ${where.join(' AND ')}
      ORDER BY d.created_at DESC
      ''',
      args,
    );
  }

  /// نسخة فندق واحد من نوع مرجعي واحد (نطاق single فقط) — تُستخدم لتفادي
  /// إنشاء مستند مكرر عند التعبئة التلقائية لمستند فندق مُزوَّد سلفاً.
  Future<Map<String, dynamic>?> getDocumentForHotelAndType(int hotelId, int documentTypeId) async {
    final db = await database;
    final rows = await db.query('documents', where: 'hotel_id = ? AND document_type_id = ?', whereArgs: [hotelId, documentTypeId], limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// بحث عام في كل مستندات النظام بالاسم — أساس "ربط مستند موجود" (مرجع
  /// جديد لمستند حالي داخل مجلد آخر، بلا أي نسخ للملف أو السجل). فلترة
  /// اختيارية بمجموعة فنادق (نفس منطق [getDocumentsInFolder] عبر
  /// [_hotelScopeWhereClause]) لأن شاشات الاختيار متعددة الفنادق تحتاج تقييد
  /// نتائج البحث بالفندق المُختار حالياً. بلا LIMIT (خلافاً للنسخة القديمة)
  /// لأن الترتيب حسب أولوية حالة الانتهاء يحدث في طبقة الـ Repository بعد
  /// الجلب، وأي قصّ للنتائج هنا قبل الترتيب قد يُسقط مستندات منتهية فعلية.
  Future<List<Map<String, dynamic>>> searchDocumentsByName(String query, {String? ownerType, List<int>? hotelIds}) async {
    final db = await database;
    final where = <String>['(d.name LIKE ? OR dt.name LIKE ?)'];
    final args = <dynamic>['%$query%', '%$query%'];
    if (ownerType != null) {
      where.add('d.owner_type = ?');
      args.add(ownerType);
    }
    if (hotelIds != null && hotelIds.isNotEmpty) {
      where.add(_hotelScopeWhereClause(hotelIds, args));
    }
    return await db.rawQuery(
      '''
      SELECT d.*, dt.name as type_name, dt.description as type_description, dt.is_mandatory, dt.requires_renewal,
             dc.name as category_name, dc.color_value as category_color, h.arabic_name as hotel_name
      FROM documents d
      LEFT JOIN document_types dt ON dt.id = d.document_type_id
      LEFT JOIN document_categories dc ON dc.id = dt.category_id
      LEFT JOIN hotels h ON h.id = d.hotel_id
      WHERE ${where.join(' AND ')}
      ORDER BY d.created_at DESC
      ''',
      args,
    );
  }

  /// كل مستندات النظام بلا أي فلترة — تُستخدم فقط لمزامنة تنبيهات انتهاء
  /// المستندات الشاملة (DocumentNotificationService)، وليست لأي شاشة عرض.
  Future<List<Map<String, dynamic>>> getAllDocuments() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.*, dt.name as type_name, dt.description as type_description, dt.is_mandatory, dt.requires_renewal,
             dc.name as category_name, dc.color_value as category_color
      FROM documents d
      LEFT JOIN document_types dt ON dt.id = d.document_type_id
      LEFT JOIN document_categories dc ON dc.id = dt.category_id
      ''');
  }

  /// كل المستندات "العامة" (hotelId=null) في النظام بغض النظر عن أي مجلد
  /// تظهر فيه — استعلام حي فقط (فلتر)، وليس عضوية مجلد فعلي: يطابق مبدأ
  /// "لا نسخ" (مستند عام يظهر هنا تلقائياً حتى لو أُنشئ من داخل أي مجلد آخر).
  Future<List<Map<String, dynamic>>> getGeneralDocuments() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.*, dt.name as type_name, dt.description as type_description, dt.is_mandatory, dt.requires_renewal,
             dc.name as category_name, dc.color_value as category_color
      FROM documents d
      LEFT JOIN document_types dt ON dt.id = d.document_type_id
      LEFT JOIN document_categories dc ON dc.id = dt.category_id
      WHERE d.hotel_id IS NULL AND d.owner_type = 'hotel'
      ORDER BY d.created_at DESC
      ''');
  }

  /// المستندات العامة أولاً ثم مستندات فندق واحد بعينه فقط — لا مستندات أي
  /// فندق آخر — تُستخدم عند اختيار مستندات لمجلد موسمي مرتبط بفندق واحد
  /// (البند سابعاً). ترتيبان منفصلان مُتّصلان (وليس استعلاماً واحداً بترتيب
  /// حسابي) حتى تبقى المجموعتان متمايزتين بوضوح للطبقة الأعلى.
  Future<List<Map<String, dynamic>>> getGeneralAndHotelDocuments(int hotelId) async {
    final general = await getGeneralDocuments();
    final db = await database;
    final hotelOnly = await db.rawQuery(
      '''
      SELECT d.*, dt.name as type_name, dt.description as type_description, dt.is_mandatory, dt.requires_renewal,
             dc.name as category_name, dc.color_value as category_color
      FROM documents d
      LEFT JOIN document_types dt ON dt.id = d.document_type_id
      LEFT JOIN document_categories dc ON dc.id = dt.category_id
      WHERE d.hotel_id = ? AND d.owner_type = 'hotel'
      ORDER BY d.created_at DESC
      ''',
      [hotelId],
    );
    return [...general, ...hotelOnly];
  }

  /// بحث/فلترة متقدّمة عبر كل مستندات "المستندات الخاصة" معاً (وليس داخل
  /// مجلد واحد فقط) — فندق، مجلد (نوع مرجعي)، ونص بحث حر، كلها اختيارية
  /// ومجتمعة بـAND. فلتر الحالة يبقى في طبقة العرض (يعتمد على تاريخ اليوم).
  Future<List<Map<String, dynamic>>> searchDocumentsAdvanced({String? query, List<int>? hotelIds, int? documentTypeId}) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (query != null && query.trim().isNotEmpty) {
      where.add('(d.name LIKE ? OR dt.name LIKE ? OR d.document_number LIKE ?)');
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }
    if (documentTypeId != null) {
      where.add('d.document_type_id = ?');
      args.add(documentTypeId);
    }
    if (hotelIds != null && hotelIds.isNotEmpty) {
      where.add(_hotelScopeWhereClause(hotelIds, args));
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    return await db.rawQuery(
      '''
      SELECT d.*, dt.name as type_name, dt.description as type_description, dt.is_mandatory, dt.requires_renewal,
             dc.name as category_name, dc.color_value as category_color, h.arabic_name as hotel_name
      FROM documents d
      LEFT JOIN document_types dt ON dt.id = d.document_type_id
      LEFT JOIN document_categories dc ON dc.id = dt.category_id
      LEFT JOIN hotels h ON h.id = d.hotel_id
      $whereClause
      ORDER BY d.created_at DESC
      ''',
      args,
    );
  }

  Future<int> insertDocumentFolderLink(int documentId, int documentTypeId) async {
    final db = await database;
    return await db.insert('document_folder_links', {'document_id': documentId, 'document_type_id': documentTypeId}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// يحذف المرجع فقط (صف document_folder_links) — لا يمسّ صف المستند نفسه
  /// ولا مرفقاته إطلاقاً، بغض النظر عن عدد المجلدات الأخرى التي يظهر بها.
  Future<int> deleteDocumentFolderLink(int documentId, int documentTypeId) async {
    final db = await database;
    return await db.delete('document_folder_links', where: 'document_id = ? AND document_type_id = ?', whereArgs: [documentId, documentTypeId]);
  }

  Future<void> setDocumentHotels(int documentId, List<int> hotelIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('document_hotels', where: 'document_id = ?', whereArgs: [documentId]);
      for (var hotelId in hotelIds) {
        await txn.insert('document_hotels', {'document_id': documentId, 'hotel_id': hotelId});
      }
    });
  }

  Future<List<int>> getDocumentHotelIds(int documentId) async {
    final db = await database;
    final rows = await db.query('document_hotels', where: 'document_id = ?', whereArgs: [documentId]);
    return rows.map((r) => r['hotel_id'] as int).toList();
  }

  /// دفعة واحدة لتفادي N+1 عند عرض قائمة مستندات فيها مستندات بنطاق 'specific'.
  Future<Map<int, List<int>>> getDocumentHotelIdsBatch(List<int> documentIds) async {
    if (documentIds.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(documentIds.length, '?').join(',');
    final rows = await db.query('document_hotels', where: 'document_id IN ($placeholders)', whereArgs: documentIds);
    final result = <int, List<int>>{};
    for (var row in rows) {
      final docId = row['document_id'] as int;
      result.putIfAbsent(docId, () => []).add(row['hotel_id'] as int);
    }
    return result;
  }

  // ---------------- مرفقات المستندات ----------------

  Future<int> insertDocumentAttachment(Map<String, dynamic> data) async { final db = await database; return await db.insert('document_attachments', data); }
  Future<List<Map<String, dynamic>>> getDocumentAttachments(int documentId) async { final db = await database; return await db.query('document_attachments', where: 'document_id = ?', whereArgs: [documentId], orderBy: 'created_at DESC'); }
  Future<Map<String, dynamic>?> getDocumentAttachmentById(int id) async {
    final db = await database;
    final rows = await db.query('document_attachments', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<List<Map<String, dynamic>>> getEmployees(int hotelId, {bool includeArchived = false}) async {
    final db = await database;
    String where = 'hotel_id = ?'; List<dynamic> args = [hotelId];
    if (!includeArchived) where += ' AND (is_archived IS NULL OR is_archived = 0)';
    return await db.query('employees', where: where, whereArgs: args, orderBy: 'name ASC');
  }
  /// كل موظفي كل الفنادق دفعة واحدة — يُستخدم في قسم "مستندات الموظفين"
  /// الذي يعرض/يصفّي عبر الفنادق كلها، بخلاف بقية استعلامات الموظفين
  /// المقيَّدة بفندق واحد.
  Future<List<Map<String, dynamic>>> getAllEmployees({bool includeArchived = false}) async {
    final db = await database;
    String? where; List<dynamic>? args;
    if (!includeArchived) { where = '(is_archived IS NULL OR is_archived = 0)'; args = []; }
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


  Future<List<Map<String, dynamic>>> getInvoices(int hotelId) async { final db = await database; return await db.query('invoices', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'id DESC'); }
  Future<int> insertInvoice(Map<String, dynamic> data) async { final db = await database; return await db.insert('invoices', data); }
  Future<Map<String, dynamic>?> findDuplicateInvoice(int hotelId, String taxNumber, String invoiceNumber) async { final db = await database; final res = await db.query('invoices', where: 'hotel_id = ? AND tax_number = ? AND invoice_number = ?', whereArgs: [hotelId, taxNumber, invoiceNumber], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<Map<String, dynamic>?> findDuplicateInvoiceByContent(int hotelId, String taxNumber, String date, double totalAmount) async { final db = await database; final res = await db.query('invoices', where: 'hotel_id = ? AND tax_number = ? AND date = ? AND total_amount = ?', whereArgs: [hotelId, taxNumber, date, totalAmount], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<List<Map<String, dynamic>>> getInvoicesBySupplier({required int hotelId, required String companyName, String? startDate, String? endDate}) async { final db = await database; String where = 'hotel_id = ? AND company_name = ?'; List<dynamic> args = [hotelId, companyName]; if (startDate != null) { where += ' AND date >= ?'; args.add(startDate); } if (endDate != null) { where += ' AND date <= ?'; args.add(endDate); } return await db.query('invoices', where: where, whereArgs: args, orderBy: 'date DESC'); }

  /// يبني شرط WHERE مشتركاً لمركز الفواتير الضريبية (يدعم فندقاً واحداً/عدة
  /// فنادق/كل الفنادق معاً) — يُستخدم من استعلامي الملخص والقائمة المُرقّمة معاً
  /// حتى تبقى نفس الفلاتر متطابقة دائماً بين البطاقات والقائمة الظاهرة تحتها.
  /// اسم مصدر التمويل "شراء آجل (مورد)" الحرفي (نفس القيمة المستخدَمة في
  /// kInvoiceFundingSources بـadd_invoice_page.dart) — الفاتورة الوحيدة غير
  /// المدفوعة وقت الإدخال؛ يُستخدم لتفسير فلتر "مرحّلة/غير مرحّلة" (راجع
  /// isPosted أدناه) بلا أي عمود جديد في قاعدة البيانات.
  static const String _deferredPurchaseSource = 'شراء آجل (مورد)';

  (String, List<Object?>) _buildInvoiceWhere({
    List<int>? hotelIds,
    String? startDate,
    String? endDate,
    String? supplierName,
    String? category,
    String? amountSource,
    String? paymentMethod,
    bool? isPosted,
    String? searchQuery,
  }) {
    final where = <String>[];
    final args = <Object?>[];
    if (hotelIds != null && hotelIds.isNotEmpty) {
      where.add('hotel_id IN (${List.filled(hotelIds.length, '?').join(',')})');
      args.addAll(hotelIds);
    }
    if (startDate != null) { where.add('date >= ?'); args.add(startDate); }
    if (endDate != null) { where.add('date <= ?'); args.add(endDate); }
    if (supplierName != null && supplierName.isNotEmpty) { where.add('company_name = ?'); args.add(supplierName); }
    if (category != null && category.isNotEmpty) {
      where.add(category == _unclassifiedCategory ? '(expense_category IS NULL OR expense_category = "")' : 'expense_category = ?');
      if (category != _unclassifiedCategory) args.add(category);
    }
    if (amountSource != null && amountSource.isNotEmpty) { where.add('amount_source = ?'); args.add(amountSource); }
    if (paymentMethod != null && paymentMethod.isNotEmpty) { where.add('payment_method = ?'); args.add(paymentMethod); }
    if (isPosted != null) {
      where.add(isPosted ? 'amount_source != ?' : 'amount_source = ?');
      args.add(_deferredPurchaseSource);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(invoice_number LIKE ? OR company_name LIKE ? OR tax_number LIKE ?)');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }
    return (where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}', args);
  }

  static const String _unclassifiedCategory = '__unclassified__';

  /// خيارات ترتيب آمنة ومحدَّدة مسبقاً (لا يُبنى ORDER BY من نص حر قادم من
  /// الواجهة مباشرة، تفادياً لأي حقن SQL) — المفتاح يُطابَق مقابل هذه
  /// القائمة فقط، وأي مفتاح غير معروف يعود للترتيب الافتراضي.
  static const Map<String, String> _invoiceSortOptions = {
    'date_desc': 'date DESC, id DESC',
    'date_asc': 'date ASC, id ASC',
    'amount_desc': 'total_amount DESC, id DESC',
    'amount_asc': 'total_amount ASC, id ASC',
    'invoice_number_desc': 'invoice_number DESC',
    'invoice_number_asc': 'invoice_number ASC',
  };

  Future<List<Map<String, dynamic>>> getInvoicesPagedFiltered({
    List<int>? hotelIds,
    String? startDate,
    String? endDate,
    String? supplierName,
    String? category,
    String? amountSource,
    String? paymentMethod,
    bool? isPosted,
    String? searchQuery,
    String sortKey = 'date_desc',
    required int limit,
    required int offset,
  }) async {
    final db = await database;
    final (whereClause, args) = _buildInvoiceWhere(hotelIds: hotelIds, startDate: startDate, endDate: endDate, supplierName: supplierName, category: category, amountSource: amountSource, paymentMethod: paymentMethod, isPosted: isPosted, searchQuery: searchQuery);
    final orderBy = _invoiceSortOptions[sortKey] ?? _invoiceSortOptions['date_desc']!;
    return await db.rawQuery('SELECT * FROM invoices $whereClause ORDER BY $orderBy LIMIT ? OFFSET ?', [...args, limit, offset]);
  }

  Future<Map<String, dynamic>> getInvoicesSummary({
    List<int>? hotelIds,
    String? startDate,
    String? endDate,
    String? supplierName,
    String? category,
    String? amountSource,
    String? paymentMethod,
    bool? isPosted,
    String? searchQuery,
  }) async {
    final db = await database;
    final (whereClause, args) = _buildInvoiceWhere(hotelIds: hotelIds, startDate: startDate, endDate: endDate, supplierName: supplierName, category: category, amountSource: amountSource, paymentMethod: paymentMethod, isPosted: isPosted, searchQuery: searchQuery);
    final totals = await db.rawQuery(
      'SELECT COUNT(*) as invoice_count, COALESCE(SUM(total_amount),0) as total_amount, COALESCE(SUM(vat),0) as total_vat, COALESCE(SUM(amount_before_tax),0) as total_before_tax, COUNT(DISTINCT company_name) as supplier_count FROM invoices $whereClause',
      args,
    );
    // "آخر فاتورة تمت إضافتها" تعني أحدث فاتورة أُدخلت فعلياً (ترتيب الإدخال
    // عبر id)، وليس بالضرورة أحدث فاتورة بحسب تاريخها المُدخَل يدوياً.
    final last = await db.rawQuery('SELECT * FROM invoices $whereClause ORDER BY id DESC LIMIT 1', args);
    return {...totals.first, 'last_invoice': last.isNotEmpty ? last.first : null};
  }

  Future<List<String>> getDistinctInvoiceSuppliers(List<int>? hotelIds) async {
    final db = await database;
    final (whereClause, args) = _buildInvoiceWhere(hotelIds: hotelIds);
    final rows = await db.rawQuery('SELECT DISTINCT company_name FROM invoices $whereClause ORDER BY company_name ASC', args);
    return rows.map((r) => r['company_name'] as String).toList();
  }

  Future<List<String>> getDistinctInvoiceCategories(List<int>? hotelIds) async {
    final db = await database;
    final (whereClause, args) = _buildInvoiceWhere(hotelIds: hotelIds);
    final baseWhere = whereClause.isEmpty ? 'WHERE expense_category IS NOT NULL AND expense_category != ""' : '$whereClause AND expense_category IS NOT NULL AND expense_category != ""';
    final rows = await db.rawQuery('SELECT DISTINCT expense_category FROM invoices $baseWhere ORDER BY expense_category ASC', args);
    return rows.map((r) => r['expense_category'] as String).toList();
  }

  Future<List<String>> getDistinctInvoiceAmountSources(List<int>? hotelIds) async {
    final db = await database;
    final (whereClause, args) = _buildInvoiceWhere(hotelIds: hotelIds);
    final baseWhere = whereClause.isEmpty ? 'WHERE amount_source IS NOT NULL AND amount_source != ""' : '$whereClause AND amount_source IS NOT NULL AND amount_source != ""';
    final rows = await db.rawQuery('SELECT DISTINCT amount_source FROM invoices $baseWhere ORDER BY amount_source ASC', args);
    return rows.map((r) => r['amount_source'] as String).toList();
  }

  Future<int> insertSupplier(Map<String, dynamic> data) async { final db = await database; return await db.insert('suppliers', data); }
  Future<Map<String, dynamic>?> getSupplierByOfficialName(int hotelId, String name) async { final db = await database; final res = await db.query('suppliers', where: 'hotel_id = ? AND official_name = ?', whereArgs: [hotelId, name], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<Map<String, dynamic>?> getSupplierByTaxNumber(int hotelId, String taxNumber) async { final db = await database; final res = await db.query('suppliers', where: 'hotel_id = ? AND tax_number = ?', whereArgs: [hotelId, taxNumber], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<int> updateSupplierCategory(int id, String category) async { final db = await database; return await db.update('suppliers', {'default_expense_category': category}, where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> searchSuppliers(int hotelId, String query) async { final db = await database; return await db.query('suppliers', where: 'hotel_id = ? AND (official_name LIKE ? OR short_name LIKE ? OR tax_number LIKE ?)', whereArgs: [hotelId, "%$query%", "%$query%", "%$query%"], limit: 10); }
  Future<Map<String, dynamic>?> getSupplierById(int id) async { final db = await database; final res = await db.query('suppliers', where: 'id = ?', whereArgs: [id], limit: 1); return res.isNotEmpty ? res.first : null; }

  // --- مديونيات ومدفوعات الموردين (شراء آجل + كشف الحساب) ---
  Future<Map<String, dynamic>?> getSupplierDebtByInvoiceId(int invoiceId) async { final db = await database; final res = await db.query('supplier_debts', where: 'invoice_id = ?', whereArgs: [invoiceId], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<int> insertSupplierDebt(Map<String, dynamic> data) async { final db = await database; return await db.insert('supplier_debts', data); }
  Future<int> updateSupplierDebtAmount(int id, double amount) async { final db = await database; return await db.update('supplier_debts', {'amount': amount}, where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getSupplierDebts(int supplierId) async { final db = await database; return await db.query('supplier_debts', where: 'supplier_id = ?', whereArgs: [supplierId], orderBy: 'created_at DESC'); }
  Future<double> getSupplierDebtsTotal(int supplierId) async { final db = await database; final res = await db.rawQuery('SELECT COALESCE(SUM(amount),0) as total FROM supplier_debts WHERE supplier_id = ?', [supplierId]); return (res.first['total'] as num).toDouble(); }

  Future<int> insertSupplierPayment(Map<String, dynamic> data) async { final db = await database; return await db.insert('supplier_payments', data); }
  Future<List<Map<String, dynamic>>> getSupplierPayments(int supplierId) async { final db = await database; return await db.query('supplier_payments', where: 'supplier_id = ?', whereArgs: [supplierId], orderBy: 'date DESC, id DESC'); }
  Future<double> getSupplierPaymentsTotal(int supplierId) async { final db = await database; final res = await db.rawQuery('SELECT COALESCE(SUM(amount),0) as total FROM supplier_payments WHERE supplier_id = ?', [supplierId]); return (res.first['total'] as num).toDouble(); }

  // --- مرفقات الفواتير ---
  Future<int> insertInvoiceAttachment(Map<String, dynamic> data) async { final db = await database; return await db.insert('invoice_attachments', data); }
  Future<List<Map<String, dynamic>>> getInvoiceAttachments(int invoiceId) async { final db = await database; return await db.query('invoice_attachments', where: 'invoice_id = ?', whereArgs: [invoiceId], orderBy: 'id ASC'); }
  Future<Map<String, dynamic>?> getInvoiceAttachmentById(int id) async { final db = await database; final res = await db.query('invoice_attachments', where: 'id = ?', whereArgs: [id], limit: 1); return res.isNotEmpty ? res.first : null; }

  // --- سجل تعديلات الفواتير (بلا إمكانية حذف عمداً — لا توجد أي دالة حذف هنا) ---
  Future<int> insertInvoiceAuditLog(Map<String, dynamic> data) async { final db = await database; return await db.insert('invoice_audit_log', data); }
  Future<List<Map<String, dynamic>>> getInvoiceAuditLog(int invoiceId) async { final db = await database; return await db.query('invoice_audit_log', where: 'invoice_id = ?', whereArgs: [invoiceId], orderBy: 'id DESC'); }

  Future<List<Map<String, dynamic>>> getContracts(int hotelId) async { final db = await database; return await db.query('contracts', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'id DESC'); }
  Future<int> insertContract(Map<String, dynamic> data) async { final db = await database; return await db.insert('contracts', data); }
  Future<void> insertContractWithPayments(Map<String, dynamic> cd, List<Map<String, dynamic>> pd) async { final db = await database; await db.transaction((txn) async { final cId = await txn.insert('contracts', cd); for (var p in pd) { p['contract_id'] = cId; await txn.insert('contract_payments', p); } }); }
  Future<List<Map<String, dynamic>>> getContractPayments(int cId) async { final db = await database; return await db.query('contract_payments', where: 'contract_id = ?', whereArgs: [cId], orderBy: 'date ASC'); }
  Future<int> insertContractPayment(Map<String, dynamic> data) async { final db = await database; return await db.insert('contract_payments', data); }

  Future<Map<String, double>> getVaultBalances(int hotelId) async { final db = await database; final res = await db.query('vault_balances', where: 'hotel_id = ?', whereArgs: [hotelId]); Map<String, double> b = {'cash': 0.0, 'bank': 0.0}; if (res.isEmpty) { await db.insert('vault_balances', {'hotel_id': hotelId, 'type': 'cash', 'balance': 0.0}); await db.insert('vault_balances', {'hotel_id': hotelId, 'type': 'bank', 'balance': 0.0}); return b; } for (var r in res) { b[r['type'] as String] = (r['balance'] as num).toDouble(); } return b; }
  Future<List<Map<String, dynamic>>> getVaultTransactions(int hotelId) async { final db = await database; return await db.query('vault_transactions', where: 'hotel_id = ?', whereArgs: [hotelId], orderBy: 'id DESC'); }
  Future<int> insertVaultTransaction(Map<String, dynamic> data) async { final db = await database; return await db.transaction((txn) async { final hId = data['hotel_id']; final type = data['source'] == 'شبكة' ? 'bank' : 'cash'; final nB = (data['balance_after'] as num).toDouble(); await txn.update('vault_balances', {'balance': nB}, where: 'hotel_id = ? AND type = ?', whereArgs: [hId, type]); return await txn.insert('vault_transactions', data); }); }

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

  // --- المستخدمون ومجموعات الصلاحيات (النسخ الاحتياطي/المزامنة وإدارة المستخدمين) ---
  Future<List<Map<String, dynamic>>> getUsers({int limit = 50, int offset = 0}) async { final db = await database; return await db.query('users', orderBy: 'id ASC', limit: limit, offset: offset); }
  Future<int> countUsers() async { final db = await database; return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users')) ?? 0; }
  Future<Map<String, dynamic>?> getUserById(int id) async { final db = await database; final res = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<int> insertUser(Map<String, dynamic> data) async { final db = await database; return await db.insert('users', data); }

  Future<List<Map<String, dynamic>>> getPermissionGroups() async { final db = await database; return await db.query('permission_groups', orderBy: 'id ASC'); }
  Future<int> insertPermissionGroup(Map<String, dynamic> data) async { final db = await database; return await db.insert('permission_groups', data); }

  /// مسار ملف قاعدة البيانات الحالي على الجهاز (لأغراض النسخ الاحتياطي/الاستعادة).
  Future<String> getDatabaseFilePath() async => join(await getDatabasesPath(), await _activeDbFileName());

  /// يغلق اتصال قاعدة البيانات المفتوح تمهيداً لاستبدال ملفها فعلياً أثناء
  /// الاستعادة من نسخة احتياطية؛ يُعاد فتحها تلقائياً عند أول استدعاء لاحق لـ [database].
  Future<void> closeForRestore() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
