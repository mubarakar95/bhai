import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../services/youpi_payment_service.dart';

class YouPiPaymentSheet extends StatefulWidget {
  final double amount;
  final String? orderId;

  const YouPiPaymentSheet({
    super.key,
    this.amount = 1.00,
    this.orderId,
  });

  static Future<bool?> show(
    BuildContext context, {
    double amount = 1.00,
    String? orderId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => YouPiPaymentSheet(
        amount: amount,
        orderId: orderId,
      ),
    );
  }

  @override
  State<YouPiPaymentSheet> createState() => _YouPiPaymentSheetState();
}

enum _PaymentStatus { initializing, active, success, failed }

class _YouPiPaymentSheetState extends State<YouPiPaymentSheet> {
  final _service = YouPiPaymentService();
  late String _orderId;
  String? _paymentId;
  String? _upiUri;
  File? _qrFile;
  _PaymentStatus _status = _PaymentStatus.initializing;
  String _statusMessage = 'Initializing payment session...';
  bool _isCopied = false;
  bool _isSaving = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _orderId = widget.orderId ?? 'ORD_BHAI_${DateTime.now().millisecondsSinceEpoch}';
    _initPaymentSession();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _initPaymentSession() async {
    setState(() {
      _status = _PaymentStatus.initializing;
      _statusMessage = 'Creating secure payment session...';
    });

    try {
      final session = await _service.createPaymentSession(
        orderId: _orderId,
        amount: widget.amount,
      );

      _paymentId = session['paymentId'] as String?;
      _upiUri = _service.buildUpiUri(
        orderId: _orderId,
        amount: widget.amount,
      );

      // Generate dynamic QR PNG
      _qrFile = await _service.generateQrPngFile(_upiUri!, 'upi_qr_$_orderId.png');

      if (!_isDisposed && mounted) {
        setState(() {
          _status = _PaymentStatus.active;
          _statusMessage = 'Awaiting payment... Auto-verifying transaction';
        });
      }

      // Start background polling
      if (_paymentId != null) {
        _startPolling(_paymentId!);
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _status = _PaymentStatus.failed;
          _statusMessage = 'Failed to initialize session: $e';
        });
      }
    }
  }

  Future<void> _startPolling(String paymentId) async {
    final result = await _service.pollPaymentStatus(
      paymentId,
      onStatusUpdate: (status) {
        if (!_isDisposed && mounted && _status == _PaymentStatus.active) {
          setState(() {
            _statusMessage = 'Status: $status. Confirming credit with bank...';
          });
        }
      },
    );

    if (_isDisposed || !mounted) return;

    if (result == 'SUCCESS') {
      setState(() {
        _status = _PaymentStatus.success;
        _statusMessage = '₹${widget.amount.toStringAsFixed(2)} Paid & Verified Successfully!';
      });
      HapticFeedback.heavyImpact();
    } else if (result == 'EXPIRED' || result == 'FAILED' || result == 'CANCELLED') {
      setState(() {
        _status = _PaymentStatus.failed;
        _statusMessage = 'Payment ended with status: $result';
      });
    }
  }

  void _copyVpa() {
    Clipboard.setData(const ClipboardData(text: YouPiPaymentService.defaultPayeeVpa));
    setState(() => _isCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UPI ID copied to clipboard: ${YouPiPaymentService.defaultPayeeVpa}'),
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isDisposed && mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _saveQrAndOpenPhonePe() async {
    if (_qrFile == null) return;
    setState(() => _isSaving = true);

    try {
      // 1. Save to Gallery
      await _service.saveQrToGallery(_qrFile!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF5F259F),
            duration: const Duration(seconds: 5),
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'QR saved to Gallery! In PhonePe:\nTap Scanner (top right) ➔ Gallery icon (bottom) ➔ Pick QR',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // 2. Launch PhonePe
      await Future.delayed(const Duration(milliseconds: 300));
      final launched = await _service.launchApp('com.phonepe.app');
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open PhonePe directly. Please open PhonePe from home screen.')),
        );
      }
    } finally {
      if (!_isDisposed && mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _copyAndOpenApp({String packageName = 'com.phonepe.app', String appName = 'PhonePe'}) async {
    Clipboard.setData(const ClipboardData(text: YouPiPaymentService.defaultPayeeVpa));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${YouPiPaymentService.defaultPayeeVpa}! Opening $appName...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    await Future.delayed(const Duration(milliseconds: 350));
    final launched = await _service.launchApp(packageName);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $appName. Please open it manually.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryPill, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Direct UPI Payment',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Instant Bank Verification · Zero Fees',
                          style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context, _status == _PaymentStatus.success),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Amount Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount to Pay', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        Text(
                          '₹${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('UPI ID', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        InkWell(
                          onTap: _copyVpa,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                const Text(
                                  YouPiPaymentService.defaultPayeeVpa,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryPill),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                                  size: 14,
                                  color: _isCopied ? Colors.green : AppColors.primaryPill,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Success View
              if (_status == _PaymentStatus.success) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 52),
                      const SizedBox(height: 10),
                      Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Verified automatically by Xiaomi MI MAX 2 Observer.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ]

              // Active / Initializing View
              else ...[
                // QR Code Display Card
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _qrFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _qrFile!,
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          )
                        : const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Point any phone camera to scan · Or use 1-tap options below',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),

                // Button 1: Save QR to Gallery & Open PhonePe
                ElevatedButton.icon(
                  onPressed: _qrFile == null || _isSaving ? null : _saveQrAndOpenPhonePe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5F259F), // PhonePe Purple
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.photo_library_rounded, size: 20),
                  label: const Text(
                    'Save QR & Open PhonePe',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                // Button 2: Copy UPI ID & Open PhonePe
                OutlinedButton.icon(
                  onPressed: () => _copyAndOpenApp(packageName: 'com.phonepe.app', appName: 'PhonePe'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: const Color(0xFF5F259F),
                    side: const BorderSide(color: Color(0xFF5F259F)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text(
                    'Copy UPI ID & Open PhonePe',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),

                // Row of alternative apps: GPay, Paytm
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _copyAndOpenApp(
                          packageName: 'com.google.android.apps.nbu.paisa.user',
                          appName: 'Google Pay',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Open GPay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _copyAndOpenApp(
                          packageName: 'net.one97.paytm',
                          appName: 'Paytm',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Open Paytm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Real-time Observer Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
