import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/models.dart';
import '../../../core/models/subscription_plan.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/utils/phone_helper.dart';
import '../../../core/widgets/subscription_upgrade_dialog.dart';
import '../../../core/providers/app_providers.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';
import '../../../core/widgets/replica_header_scaffold.dart';
import '../../../core/widgets/photo_crop_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSaving = false;

  Widget _buildAvatarWidget(Owner owner, double size) {
    final avatar = owner.avatarUrl;
    if (avatar != null && avatar.isNotEmpty) {
      return AppImageHelper.buildImage(
        avatar,
        fit: BoxFit.cover,
        width: size,
        height: size,
        placeholder: _buildInitialsAvatar(owner, size),
      );
    }
    return _buildInitialsAvatar(owner, size);
  }

  Widget _buildInitialsAvatar(Owner owner, double size) {
    final name = owner.fullName.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'O';
    return Container(
      width: size,
      height: size,
      color: AppColors.primaryPill,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showAvatarPickerModal(BuildContext context, Owner owner) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Update Profile Avatar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.primaryPill, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await pickAndCropImage(
                    context,
                    source: ImageSource.camera,
                    cropShape: CropShape.circle,
                    title: 'Crop Profile Avatar',
                  );
                  if (file != null) {
                    setState(() => _isSaving = true);
                    await ref.read(authProvider.notifier).uploadAndSetAvatar(file);
                    if (mounted) {
                      setState(() => _isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile picture updated successfully!')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.primaryPill, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Choose from Photo Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await pickAndCropImage(
                    context,
                    source: ImageSource.gallery,
                    cropShape: CropShape.circle,
                    title: 'Crop Profile Avatar',
                  );
                  if (file != null) {
                    setState(() => _isSaving = true);
                    await ref.read(authProvider.notifier).uploadAndSetAvatar(file);
                    if (mounted) {
                      setState(() => _isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile picture updated successfully!')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, Owner owner) {
    final formKey = GlobalKey<FormState>();
    final isPlaceholder = PhoneHelper.isPlaceholderPhoneNumber(owner.mobileNo);
    final nameCtrl = TextEditingController(text: owner.fullName);
    final businessCtrl = TextEditingController(text: owner.businessName ?? '');
    final addressCtrl = TextEditingController(text: owner.businessAddress ?? '');
    final mobileCtrl = TextEditingController(
      text: isPlaceholder ? '' : PhoneHelper.cleanPhoneNumber(owner.mobileNo),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Owner Profile'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: businessCtrl,
                  decoration: const InputDecoration(labelText: 'Business / PG Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Business / Official Address',
                    hintText: 'e.g. Plot 45, Sector 62, Noida, UP (appears on PDF reports)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: mobileCtrl,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number *',
                    hintText: '9876543210',
                    prefixText: '+91 ',
                    helperText: isPlaceholder ? 'Please enter your actual 10-digit mobile' : null,
                    helperStyle: const TextStyle(color: Color(0xFFD97706)),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: PhoneHelper.validateMobileNumber,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              setState(() => _isSaving = true);
              final cleanMobile = PhoneHelper.cleanPhoneNumber(mobileCtrl.text.trim());
              final error = await ref.read(authProvider.notifier).updateProfile(
                fullName: nameCtrl.text.trim(),
                businessName: businessCtrl.text.trim(),
                businessAddress: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                mobileNo: cleanMobile,
              );
              if (mounted && context.mounted) {
                setState(() => _isSaving = false);
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $error'), backgroundColor: AppColors.alertRed),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Owner profile details updated!')),
                  );
                }
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPlanCard(BuildContext context, Owner owner) {
    final isPaid = SubscriptionPlanConfig.isPaidPlan(owner.subscriptionPlan);
    final isTrial = SubscriptionPlanConfig.isTrialActive(owner);
    final trialDaysRemaining = SubscriptionPlanConfig.getTrialDaysRemaining(owner);
    final currentPlanConfig = SubscriptionPlanConfig.getEffectivePlan(owner);
    final isFree = !isPaid && !isTrial;
    final isCloudSyncSupported = isPaid || isTrial;

    final properties = ref.watch(propertiesProvider).value ?? [];
    final stays = ref.watch(staysProvider).value ?? [];
    final activeGuestsCount = stays.where((s) => s.status == 'active').length;
    final pendingCount = dbService.pendingSyncCount;

    return Column(
      children: [
        // 1. Subscription & Plan Details Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isFree
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFEF3C7),
                      Color(0xFFFDE68A),
                    ],
                  ),
            color: isFree ? AppColors.glassCard : null,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isFree
                  ? const Color(0xFF347AE2).withOpacity(0.3)
                  : const Color(0xFFF59E0B).withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isFree
                          ? const Color(0xFF347AE2)
                          : (isTrial ? const Color(0xFFD97706) : const Color(0xFFB45309)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isFree ? Icons.shield_outlined : Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                currentPlanConfig.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isFree ? AppColors.textMain : const Color(0xFF78350F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isTrial
                                    ? const Color(0xFFD97706)
                                    : (isPaid ? const Color(0xFFB45309) : AppColors.primaryPill),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isTrial
                                    ? '60D TRIAL'
                                    : (isPaid ? 'ACTIVE PRO' : 'BASIC PLAN'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTrial
                              ? '$trialDaysRemaining days left in trial • Converts to Basic after'
                              : (isPaid
                                  ? currentPlanConfig.priceDisplay
                                  : '60-Day Trial Expired • Basic Plan active'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isFree
                                ? AppColors.alertRed
                                : (isTrial ? const Color(0xFFB45309) : const Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                color: isFree ? AppColors.glassBorder : const Color(0x33D97706),
                height: 1,
              ),
              const SizedBox(height: 14),

              // Quota / Usage status pills
              Text(
                'PLAN QUOTAS & CAPACITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: isFree ? AppColors.textSecondary : const Color(0xFF78350F),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildQuotaCard(
                      'Properties',
                      '${properties.length} / ${currentPlanConfig.maxPropertiesDisplay}',
                      Icons.apartment_rounded,
                      isFree,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuotaCard(
                      'Max Rooms',
                      currentPlanConfig.maxRoomsDisplay,
                      Icons.meeting_room_rounded,
                      isFree,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuotaCard(
                      'Guests',
                      '$activeGuestsCount / ${currentPlanConfig.maxGuestsDisplay}',
                      Icons.people_rounded,
                      isFree,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Plan features
              ...currentPlanConfig.features.take(3).map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: isFree ? AppColors.primaryPill : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 13,
                                color: isFree ? AppColors.textMain : const Color(0xFF78350F),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => SubscriptionUpgradeDialog.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFree ? AppColors.primaryPill : const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isFree
                          ? 'PURCHASE PRO PLAN'
                          : (isTrial ? 'UPGRADE / EXTEND PRO PLAN' : 'CHANGE / UPGRADE PLAN'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Cloud Sync & Offline Backup / Restore Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isCloudSyncSupported
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B))
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isCloudSyncSupported
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: isCloudSyncSupported
                          ? const Color(0xFF059669)
                          : const Color(0xFF64748B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCloudSyncSupported
                              ? 'Cloud Sync Engine'
                              : 'Offline Device Storage',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isCloudSyncSupported
                              ? (pendingCount > 0
                                  ? '$pendingCount changes queued for cloud sync'
                                  : 'All data saved locally & synced to Cloud (Auto-syncs every 3 mins)')
                              : 'Free Tier stores data securely on this device (No Cloud Sync)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCloudSyncSupported && pendingCount > 0
                                ? AppColors.alertRed
                                : AppColors.textSecondary,
                            fontWeight: isCloudSyncSupported && pendingCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCloudSyncSupported
                          ? (pendingCount > 0
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFD1FAE5))
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCloudSyncSupported
                          ? (pendingCount > 0 ? 'QUEUED' : 'ACTIVE')
                          : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isCloudSyncSupported
                            ? (pendingCount > 0
                                ? AppColors.alertRed
                                : const Color(0xFF065F46))
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isCloudSyncSupported
                    ? 'Bhai App caches all properties, rooms, guests and payments directly on your device. Database reads and writes are reduced by up to 90% for lightning-fast offline operation. Changes automatically sync to Cloud in the background.'
                    : 'Your entries are saved on this phone. Automatic cloud synchronization is disabled on the Free tier. You can use the Export & Import options below to manually backup or restore your data anytime, or upgrade to Pro to enable instant cloud syncing.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),

              if (isCloudSyncSupported)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Syncing local data with Cloud...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      final synced = await dbService.syncPendingData();
                      if (context.mounted) {
                        setState(() {});
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              synced > 0
                                  ? 'Successfully synced $synced pending items to Cloud!'
                                  : 'All data is already up-to-date with Cloud.',
                            ),
                            backgroundColor: AppColors.verifiedGreen,
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryPill),
                      foregroundColor: AppColors.primaryPill,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text(
                      'SYNC NOW WITH CLOUD',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),

              if (isCloudSyncSupported) const SizedBox(height: 10),

              // Export & Import Offline Backup Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final jsonStr = await dbService.exportOfflineData();
                          final tempDir = await getTemporaryDirectory();
                          final file = File(
                              '${tempDir.path}/bhai_app_backup_${DateTime.now().millisecondsSinceEpoch}.json');
                          await file.writeAsString(jsonStr);

                          await Share.shareXFiles(
                            [XFile(file.path)],
                            subject: 'Bhai App Offline Data Backup',
                            text: 'Bhai App Offline Data Backup (${DateFormat('dd-MMM-yyyy').format(DateTime.now())})',
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to export backup: $e'),
                                backgroundColor: AppColors.alertRed,
                              ),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isCloudSyncSupported
                              ? const Color(0xFFCBD5E1)
                              : AppColors.primaryPill,
                        ),
                        foregroundColor: isCloudSyncSupported
                            ? AppColors.textMain
                            : AppColors.primaryPill,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text(
                        'EXPORT BACKUP',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final pickedFiles = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['json'],
                          );
                          if (pickedFiles.isNotEmpty && pickedFiles.first.path != null) {
                            final file = File(pickedFiles.first.path!);
                            final content = await file.readAsString();
                            final stats = await dbService.importOfflineData(content);

                            // Refresh providers
                            ref.invalidate(propertiesProvider);
                            ref.invalidate(staysProvider);

                            if (context.mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Imported successfully! Restored ${stats.properties} properties, ${stats.rooms} rooms, and ${stats.guests} guests.',
                                  ),
                                  backgroundColor: AppColors.verifiedGreen,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to import backup: $e'),
                                backgroundColor: AppColors.alertRed,
                              ),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isCloudSyncSupported
                              ? const Color(0xFFCBD5E1)
                              : AppColors.primaryPill,
                        ),
                        foregroundColor: isCloudSyncSupported
                            ? AppColors.textMain
                            : AppColors.primaryPill,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text(
                        'IMPORT BACKUP',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuotaCard(String title, String value, IconData icon, bool isFree) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isFree ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: isFree ? AppColors.primaryPill : const Color(0xFFB45309)),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerState = ref.watch(authProvider);

    return ReplicaHeaderScaffold(
      title: 'Settings',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSaving) const LinearProgressIndicator(color: AppColors.primaryPill),

              // Owner Profile Card
              ownerState.when(
                data: (owner) {
                  if (owner == null) return const SizedBox();
                  final isPaid = SubscriptionPlanConfig.isPaidPlan(owner.subscriptionPlan);
                  final isTrial = SubscriptionPlanConfig.isTrialActive(owner);
                  final trialDaysLeft = SubscriptionPlanConfig.getTrialDaysRemaining(owner);
                  final isOwnerPremium = isPaid || isTrial;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.glassCard,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.glassBorder),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Avatar with Camera Overlay
                                GestureDetector(
                                  onTap: () => _showAvatarPickerModal(context, owner),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.primaryPill, width: 2),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x1F000000),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: _buildAvatarWidget(owner, 60),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryPill,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        owner.fullName,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        owner.businessName ?? 'Personal Ledger',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (owner.businessAddress != null && owner.businessAddress!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          owner.businessAddress!,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.textMuted,
                                                fontSize: 11,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isOwnerPremium ? const Color(0xFFFEF3C7) : AppColors.verifiedBg,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isOwnerPremium ? const Color(0xFFF59E0B) : AppColors.verifiedGreen,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isOwnerPremium) ...[
                                              const Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFFB45309)),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              isTrial
                                                  ? 'PRO TRIAL (${trialDaysLeft}d)'
                                                  : (isPaid ? 'PRO PLAN' : 'BASIC PLAN'),
                                              style: TextStyle(
                                                color: isOwnerPremium ? const Color(0xFFB45309) : AppColors.verifiedGreen,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _showEditProfileDialog(context, owner),
                                  icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryPill, size: 26),
                                  tooltip: 'Edit Profile Info',
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: AppColors.glassBorder),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final isPlaceholder = PhoneHelper.isPlaceholderPhoneNumber(owner.mobileNo);
                                    return Row(
                                      children: [
                                        Icon(
                                          isPlaceholder ? Icons.warning_amber_rounded : Icons.phone_rounded,
                                          size: 15,
                                          color: isPlaceholder ? const Color(0xFFD97706) : AppColors.primaryPill,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isPlaceholder
                                                ? 'Action required: Update mobile'
                                                : PhoneHelper.formatDisplayPhone(owner.mobileNo),
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: isPlaceholder ? const Color(0xFFD97706) : AppColors.textMain,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isPlaceholder)
                                          GestureDetector(
                                            onTap: () => _showEditProfileDialog(context, owner),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFFDE68A)),
                                              ),
                                              child: const Text(
                                                'Update',
                                                style: TextStyle(
                                                  color: Color(0xFF92400E),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.email_rounded, size: 15, color: AppColors.primaryPill),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        owner.email,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildPremiumPlanCard(context, owner),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error loading profile: $e'),
              ),
              const SizedBox(height: 24),

              // Font Size Customization Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.glassCard,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Text Display Size',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Scale text font size app-wide for optimal readability.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Consumer(
                      builder: (context, ref, child) {
                        final currentScale = ref.watch(textScaleFactorProvider);
                        final options = [
                          {'label': 'Small', 'value': 0.85},
                          {'label': 'Medium', 'value': 1.0},
                          {'label': 'Large', 'value': 1.15},
                        ];

                        return Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.neutralPill,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            children: options.map((opt) {
                              final val = opt['value'] as double;
                              final label = opt['label'] as String;
                              final isSelected = (currentScale - val).abs() < 0.05;

                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    ref.read(textScaleFactorProvider.notifier).setScale(val);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primaryPill : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected ? Colors.white : AppColors.textMain,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Info & Navigation Cards
              Text(
                'Information & Support',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.glassCard,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.neutralPill,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: AppColors.textMain),
                        ),
                        title: const Text('About Us', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Purpose, security compliance & app architecture'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AboutUsScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, color: AppColors.glassBorder),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.neutralPill,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.support_agent_rounded, color: AppColors.textMain),
                        ),
                        title: const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Mubarak Technologies, Kollam, Kerala, India'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ContactUsScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, color: AppColors.glassBorder),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.neutralPill,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.privacy_tip_outlined, color: AppColors.textMain),
                        ),
                        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Data protection, Aadhaar compliance & rights'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showPrivacyPolicyDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Logout & Account Deletion Actions
              Center(
                child: Column(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('DISCONNECT LEDGER (LOGOUT)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.alertRed,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      ),
                      onPressed: () => _showDeleteAccountDialog(context),
                      icon: const Icon(Icons.delete_forever_rounded, size: 20),
                      label: const Text('Delete Account & All Data', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.shield_rounded, color: AppColors.brandBlue, size: 28),
            SizedBox(width: 10),
            Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Bhai App Privacy & Data Protection Policy',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 8),
                Text(
                  'Last Updated: October 2026\nOperated by Mubarak Technologies (Kollam, Kerala, India).\n',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '1. Information We Collect\n'
                  '• Account Info: Name, mobile number, business/camp name, and email address.\n'
                  '• Property & Rental Records: Room identifiers, tariffs, and check-in/out records.\n'
                  '• Tenant Identity Data: Tenant names, contact numbers, Aadhaar details, emergency contacts, and photos collected strictly for mandatory local police reporting and tenant verification.\n',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                Text(
                  '2. Camera & Photo Permissions\n'
                  'Camera and Photo Library permissions are used exclusively to allow property managers to photograph tenant physical ID proofs, capture facial identity photos for police verification reports, and upload property images.\n',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                Text(
                  '3. Data Protection & Security\n'
                  'All data in transit is encrypted using industry-standard TLS 1.3 / HTTPS. Cloud databases enforce strict Row Level Security (RLS) ensuring property owners can only access records they have created.\n',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                Text(
                  '4. Tenant & Owner Rights\n'
                  'Camp owners have full authority to modify, export (as official PDF), or delete any guest profile, stay record, or ledger entry at any time.\n',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                Text(
                  '5. Account & Data Deletion\n'
                  'You may delete your account and all associated data at any time via the "Delete Account & All Data" button in Settings. Upon confirmation, all properties, rooms, tenant logs, and payment records are immediately and permanently wiped.\n',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                Text(
                  '6. Contact Information\n'
                  'For privacy inquiries or compliance questions, contact us via the Contact Us screen or at privacy@mubaraktech.com.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPill,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I UNDERSTAND'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.alertRed, size: 28),
            SizedBox(width: 10),
            Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your account?\n\n'
          '⚠️ This action is irreversible. All your registered properties, rooms, tenant check-in records, payment ledgers, and identity proofs will be permanently erased from both our Cloud database and this device.\n\n'
          'Complies with Google Play & Apple App Store account deletion requirements.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isSaving = true);
              try {
                await ref.read(authProvider.notifier).deleteAccount();
              } catch (e) {
                if (mounted) {
                  setState(() => _isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e'),
                      backgroundColor: AppColors.alertRed,
                    ),
                  );
                }
              }
            },
            child: const Text('PERMANENTLY DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
