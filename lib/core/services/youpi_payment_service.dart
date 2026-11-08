import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:qr/qr.dart';
import 'package:url_launcher/url_launcher.dart';

class YouPiPaymentResult {
  final bool success;
  final String paymentId;
  final String orderId;
  final double amount;
  final String message;

  const YouPiPaymentResult({
    required this.success,
    required this.paymentId,
    required this.orderId,
    required this.amount,
    required this.message,
  });
}

class YouPiPaymentService {
  static const String defaultApiBase = 'https://150-230-239-218.sslip.io';
  static const String defaultPayeeVpa = '8281944281@ybl';
  static const String defaultPayeeName = 'Mubarak Technologies';

  static const MethodChannel _platform = MethodChannel('com.bhai.room_rental/upi_share');

  final String apiBase;

  YouPiPaymentService({this.apiBase = defaultApiBase});

  /// 1. Create a payment session on the YouPI-PG server
  Future<Map<String, dynamic>> createPaymentSession({
    required String orderId,
    required double amount,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$apiBase/api/v1/payments');
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');

      final body = jsonEncode({
        'orderId': orderId,
        'amount': amount,
      });
      req.write(body);

      final resp = await req.close();
      final respBody = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(respBody) as Map<String, dynamic>;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to create payment session (HTTP ${resp.statusCode})');
      }
    } finally {
      client.close();
    }
  }

  /// 1b. Opens the secure web checkout portal directly in the browser
  Future<bool> openWebCheckout({
    required String orderId,
    required double amount,
  }) async {
    final session = await createPaymentSession(
      orderId: orderId,
      amount: amount,
    );

    final paymentId = session['paymentId'] as String?;
    final checkoutUrl = (session['checkoutUrl'] as String?) ?? '$apiBase/checkout/$paymentId';

    final uri = Uri.parse(checkoutUrl);
    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  /// 2. Build canonical UPI URI for QR code & intent
  String buildUpiUri({
    required String orderId,
    required double amount,
    String payeeVpa = defaultPayeeVpa,
    String payeeName = defaultPayeeName,
  }) {
    final amtStr = amount.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final encodedNote = Uri.encodeComponent(orderId);
    return 'upi://pay?pa=$payeeVpa&pn=$encodedName&am=$amtStr&cu=INR&tn=$encodedNote';
  }

  /// 3. Generates a crisp, scannable QR Code PNG image and saves it to a local file.
  Future<File> generateQrPngFile(String upiUri, String filename) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');

    final qrCode = QrCode.fromData(
      data: upiUri,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    const pixelScale = 14;
    const margin = 4 * pixelScale;
    final size = moduleCount * pixelScale + margin * 2;

    final image = img.Image(width: size, height: size);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));

    for (int x = 0; x < moduleCount; x++) {
      for (int y = 0; y < moduleCount; y++) {
        if (qrImage.isDark(y, x)) {
          img.fillRect(
            image,
            x1: margin + x * pixelScale,
            y1: margin + y * pixelScale,
            x2: margin + (x + 1) * pixelScale - 1,
            y2: margin + (y + 1) * pixelScale - 1,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
      }
    }

    final pngBytes = img.encodePng(image);
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }

  /// 4. Dispatches the QR Code Image directly to PhonePe via Android ACTION_SEND.
  /// PhonePe automatically scans the QR code from the stream and directly opens the Payment Screen!
  Future<bool> shareQrToPhonePe(File qrFile, {String? targetPackage = 'com.phonepe.app'}) async {
    try {
      final ok = await _platform.invokeMethod<bool>('shareQrToUpi', {
        'filePath': qrFile.path,
        'packageName': targetPackage,
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('shareQrToPhonePe error: $e');
      return false;
    }
  }

  /// 4b. Saves the generated QR Code to device Gallery (Pictures/BhaiPayments)
  Future<String?> saveQrToGallery(File qrFile) async {
    try {
      final uriString = await _platform.invokeMethod<String>('saveQrToGallery', {
        'filePath': qrFile.path,
      });
      return uriString;
    } catch (e) {
      debugPrint('saveQrToGallery error: $e');
      return null;
    }
  }

  /// 4c. Launches an app by package name directly (e.g. com.phonepe.app)
  Future<bool> launchApp(String packageName) async {
    try {
      final ok = await _platform.invokeMethod<bool>('launchApp', {
        'packageName': packageName,
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('launchApp error: $e');
      return false;
    }
  }

  /// Fallback: launch native UPI Intent (for devices where intent is not blocked)
  Future<bool> launchUpiIntent(String upiUri) async {
    final uri = Uri.parse(upiUri);
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error launching UPI intent: $e');
      return false;
    }
  }

  /// 5. Poll session status until SUCCESS, EXPIRED, or FAILED
  Future<String> pollPaymentStatus(
    String paymentId, {
    Duration timeout = const Duration(minutes: 5),
    Duration interval = const Duration(seconds: 2),
    void Function(String status)? onStatusUpdate,
  }) async {
    final client = HttpClient();
    final deadline = DateTime.now().add(timeout);

    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final uri = Uri.parse('$apiBase/api/v1/payments/$paymentId');
          final req = await client.getUrl(uri);
          final resp = await req.close();
          if (resp.statusCode == 200) {
            final body = await resp.transform(utf8.decoder).join();
            final data = jsonDecode(body) as Map<String, dynamic>;
            final status = (data['status'] ?? '').toString().toUpperCase();

            onStatusUpdate?.call(status);

            if (status == 'SUCCESS') {
              return 'SUCCESS';
            } else if (status == 'EXPIRED' || status == 'FAILED' || status == 'CANCELLED') {
              return status;
            }
          }
        } catch (e) {
          debugPrint('Polling error: $e');
        }

        await Future.delayed(interval);
      }
      return 'TIMEOUT';
    } finally {
      client.close();
    }
  }
}
