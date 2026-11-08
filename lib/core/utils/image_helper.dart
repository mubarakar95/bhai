import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

class AppImageHelper {
  /// Returns an ImageProvider suitable for network URLs or local file paths,
  /// with optional memory-cache resizing to avoid large RAM consumption.
  static ImageProvider? getImageProvider(
    String? urlOrPath, {
    int? targetWidth,
    int? targetHeight,
  }) {
    if (urlOrPath == null || urlOrPath.trim().isEmpty) return null;
    final trimmed = urlOrPath.trim();

    ImageProvider provider;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      provider = NetworkImage(trimmed);
    } else {
      try {
        final file = File(trimmed);
        if (file.existsSync()) {
          provider = FileImage(file);
        } else {
          return null;
        }
      } catch (_) {
        return null;
      }
    }

    if (targetWidth != null || targetHeight != null) {
      return ResizeImage.resizeIfNeeded(targetWidth, targetHeight, provider);
    }
    return provider;
  }

  /// Builds an image widget supporting both network URLs, local files, and fallbacks
  /// with automatic GPU cache sizing to reduce RAM usage and ensure fast 60fps scrolling.
  static Widget buildImage(
    String? urlOrPath, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    Widget content;
    final trimmed = urlOrPath?.trim() ?? '';
    final calcCacheW = cacheWidth ?? (width != null && width.isFinite ? (width * 2.5).round() : null);
    final calcCacheH = cacheHeight ?? (height != null && height.isFinite ? (height * 2.5).round() : null);

    if (trimmed.isEmpty) {
      content = placeholder ?? _defaultPlaceholder(width, height);
    } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      content = Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: calcCacheW,
        cacheHeight: calcCacheH,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder ?? _defaultPlaceholder(width, height, isLoading: true);
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? _defaultPlaceholder(width, height);
        },
      );
    } else {
      final file = File(trimmed);
      if (file.existsSync()) {
        content = Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: calcCacheW,
          cacheHeight: calcCacheH,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? _defaultPlaceholder(width, height);
          },
        );
      } else {
        content = errorWidget ?? _defaultPlaceholder(width, height);
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: content,
      );
    }
    return content;
  }

  /// Builds a CircleAvatar or Circular Image supporting both types,
  /// resized to target radius so large photos decode into tiny memory bitmaps.
  static Widget buildCircularAvatar(
    String? urlOrPath, {
    double radius = 24,
    String? initials,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final targetDim = radius.isFinite ? (radius * 4).round() : null;
    final imageProvider = getImageProvider(
      urlOrPath,
      targetWidth: targetDim,
      targetHeight: targetDim,
    );
    if (imageProvider != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? AppColors.primaryPill.withOpacity(0.1),
        backgroundImage: imageProvider,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primaryPill.withOpacity(0.1),
      child: Text(
        (initials != null && initials.isNotEmpty) ? initials.substring(0, 1).toUpperCase() : 'G',
        style: TextStyle(
          color: foregroundColor ?? AppColors.primaryPill,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  static Widget _defaultPlaceholder(double? width, double? height, {bool isLoading = false}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPill),
              )
            : const Icon(Icons.person, color: Colors.grey, size: 24),
      ),
    );
  }
}
