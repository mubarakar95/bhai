import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class _CompressParams {
  final Uint8List bytes;
  final int maxDimension;
  final int quality;

  _CompressParams({
    required this.bytes,
    required this.maxDimension,
    required this.quality,
  });
}

Uint8List _compressIsolate(_CompressParams params) {
  try {
    final decoded = img.decodeImage(params.bytes);
    if (decoded == null) return params.bytes;

    // Fix EXIF orientation (ensures mobile photos are correctly rotated)
    final oriented = img.bakeOrientation(decoded);

    img.Image resized = oriented;
    if (oriented.width > params.maxDimension || oriented.height > params.maxDimension) {
      if (oriented.width >= oriented.height) {
        resized = img.copyResize(
          oriented,
          width: params.maxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resized = img.copyResize(
          oriented,
          height: params.maxDimension,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    final jpgBytes = img.encodeJpg(resized, quality: params.quality);
    return Uint8List.fromList(jpgBytes);
  } catch (e) {
    debugPrint('Image compression error in isolate: $e');
    return params.bytes;
  }
}

class AppImageOptimizer {
  /// Compresses and resizes image bytes in a background isolate.
  static Future<Uint8List> optimizeBytes(
    Uint8List rawBytes, {
    int maxDimension = 600,
    int quality = 82,
  }) async {
    return compute(
      _compressIsolate,
      _CompressParams(
        bytes: rawBytes,
        maxDimension: maxDimension,
        quality: quality,
      ),
    );
  }

  /// Compresses and resizes an image file, returning a lightweight JPEG File.
  static Future<File> optimizeFile(
    File file, {
    int maxDimension = 600,
    int quality = 82,
  }) async {
    try {
      final rawBytes = await file.readAsBytes();
      final compressedBytes = await optimizeBytes(
        rawBytes,
        maxDimension: maxDimension,
        quality: quality,
      );

      final tempDir = await getTemporaryDirectory();
      final fileName = 'opt_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last.split('.').first}.jpg';
      final optimizedFile = File('${tempDir.path}/$fileName');
      await optimizedFile.writeAsBytes(compressedBytes);
      return optimizedFile;
    } catch (e) {
      debugPrint('AppImageOptimizer.optimizeFile failed ($e), returning original');
      return file;
    }
  }

  /// Automatically chooses the optimal resolution and compression based on bucket type:
  /// - `person-photos`: 512x512 max dimension (profile avatars), ~35-50 KB
  /// - `aadhaar-photos`: 1280px max dimension (clear document text & QR codes), ~90-140 KB
  /// - default: 1024px max dimension, ~70-110 KB
  static Future<File> optimizeForBucket(String bucketName, File file) async {
    final cleanBucket = bucketName.toLowerCase();
    if (cleanBucket.contains('person') || cleanBucket.contains('avatar') || cleanBucket.contains('profile')) {
      return optimizeFile(file, maxDimension: 512, quality: 82);
    } else if (cleanBucket.contains('aadhaar') || cleanBucket.contains('id') || cleanBucket.contains('doc')) {
      return optimizeFile(file, maxDimension: 1280, quality: 82);
    } else {
      return optimizeFile(file, maxDimension: 1024, quality: 80);
    }
  }
}
