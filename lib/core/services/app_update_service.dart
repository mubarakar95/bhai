import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';

class AppConfig {
  static const String appVersion = '1.2.0';
  static const int buildNumber = 3;
  static const String defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.bhaiapp.bhaiapp';
}

class AppUpdateInfo {
  final String minVersion;
  final int minBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final bool forceUpdate;
  final String title;
  final String message;
  final String playStoreUrl;

  const AppUpdateInfo({
    required this.minVersion,
    required this.minBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.forceUpdate,
    required this.title,
    required this.message,
    required this.playStoreUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      minVersion: json['min_version'] as String? ?? '1.0.0',
      minBuildNumber: json['min_build_number'] as int? ?? 1,
      latestVersion: json['latest_version'] as String? ?? '1.2.0',
      latestBuildNumber: json['latest_build_number'] as int? ?? 3,
      forceUpdate: json['force_update'] as bool? ?? false,
      title: json['title'] as String? ?? 'App Update Required',
      message: json['message'] as String? ??
          'A new update is available on Google Play Store with critical improvements. Please update to continue using the application.',
      playStoreUrl: json['play_store_url'] as String? ?? AppConfig.defaultPlayStoreUrl,
    );
  }

  bool get requiresForceUpdate {
    // If the installed build number is less than required minimum
    if (AppConfig.buildNumber < minBuildNumber) return true;

    // Or if forceUpdate is explicitly enabled and version is lower than minVersion
    if (forceUpdate && _isVersionLower(AppConfig.appVersion, minVersion)) {
      return true;
    }

    return false;
  }

  bool get isOptionalUpdateAvailable {
    if (requiresForceUpdate) return false;
    if (AppConfig.buildNumber < latestBuildNumber) return true;
    return _isVersionLower(AppConfig.appVersion, latestVersion);
  }

  static bool _isVersionLower(String current, String target) {
    try {
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final targetParts = target.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final len = currentParts.length > targetParts.length ? currentParts.length : targetParts.length;

      for (int i = 0; i < len; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final t = i < targetParts.length ? targetParts[i] : 0;
        if (c < t) return true;
        if (c > t) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  AppUpdateInfo? _cachedInfo;
  AppUpdateInfo? get cachedInfo => _cachedInfo;

  Future<AppUpdateInfo?> fetchUpdateInfo() async {
    try {
      final response = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', 'app_version_config')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final data = Map<String, dynamic>.from(response['value'] as Map);
        _cachedInfo = AppUpdateInfo.fromJson(data);
        return _cachedInfo;
      }
    } catch (e) {
      debugPrint('Notice checking app update config: $e');
    }
    return null;
  }

  static Future<void> openPlayStore([String? customUrl]) async {
    final urlStr = customUrl ?? AppConfig.defaultPlayStoreUrl;
    final Uri uri = Uri.parse(urlStr);

    try {
      // Try opening in Play Store app directly if possible
      final marketUri = Uri.parse('market://details?id=com.bhaiapp.bhaiapp');
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to launch Play Store: $e');
    }
  }

  static void showForceUpdateModal(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPill.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.system_update_rounded,
                      size: 40,
                      color: AppColors.primaryPill,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  info.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  info.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Installed Version',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        'v${AppConfig.appVersion} (${AppConfig.buildNumber})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Required Version',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'v${info.minVersion} (${info.minBuildNumber})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPill,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.shop_two_rounded, size: 20),
                    label: const Text(
                      'Update on Google Play',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () => openPlayStore(info.playStoreUrl),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
