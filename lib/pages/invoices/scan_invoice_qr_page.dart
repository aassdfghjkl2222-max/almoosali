import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../services/zatca_qr_parser.dart';
import 'add_invoice_page.dart';

/// شاشة كاميرا لمسح رمز QR الخاص بفاتورة ضريبية سعودية (ZATCA). عند نجاح
/// القراءة تُرجِع [ZatcaInvoiceData] عبر Navigator.pop لتُستهلَك مباشرة في
/// AddInvoicePage(qrPrefill:). عند إلغاء المستخدم أو اختياره "إدخال يدوي"
/// تُرجِع null — المستدعي يفتح AddInvoicePage فارغة كالمعتاد في هذه الحالة.
class ScanInvoiceQrPage extends StatefulWidget {
  final Hotel hotel;
  const ScanInvoiceQrPage({super.key, required this.hotel});

  @override
  State<ScanInvoiceQrPage> createState() => _ScanInvoiceQrPageState();
}

class _ScanInvoiceQrPageState extends State<ScanInvoiceQrPage> {
  final _controller = MobileScannerController();
  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  bool _isTorchOn = false;

  /// يمنع معالجة نفس الإطار أو إطارات متتالية أثناء عرض رسالة خطأ سابقة —
  /// يُعاد ضبطه فقط عند "إعادة المحاولة" الصريحة من المستخدم.
  bool _isPaused = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isPaused) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;

    setState(() => _isPaused = true);
    try {
      final data = parseZatcaQr(raw);
      Navigator.pop(context, data);
    } on ZatcaQrParseException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = "تعذّر قراءة الرمز — تأكد أنه رمز فاتورة ضريبية سعودية صالح");
    }
  }

  void _retry() {
    setState(() {
      _errorMessage = null;
      _isPaused = false;
    });
  }

  /// طلب صريح للإدخال اليدوي (بعد فشل قراءة) — يستبدل شاشة المسح بشاشة
  /// "إضافة فاتورة" فارغة مباشرة (بدل مجرد إرجاع null، الذي قد يلتبس مع
  /// إلغاء بسيط بزر الرجوع العادي؛ راجع InvoicesPage._openQrScan).
  void _enterManually() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AddInvoicePage(hotel: widget.hotel)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("مسح فاتورة ضريبية", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: _identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: "الفلاش",
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          _buildScanFrame(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                child: const Text("وجّه الكاميرا نحو رمز QR في الفاتورة الضريبية", style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ),
          if (_errorMessage != null) _buildErrorOverlay(),
        ],
      ),
    );
  }

  Widget _buildScanFrame() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: _errorMessage != null ? Colors.red : _identityColor, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: _enterManually,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                    child: const Text("إدخال يدوي"),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _retry,
                    style: FilledButton.styleFrom(backgroundColor: _identityColor),
                    child: const Text("إعادة المحاولة"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
