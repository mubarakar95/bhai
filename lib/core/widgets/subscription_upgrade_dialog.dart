import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/colors.dart';
import '../models/subscription_plan.dart';
import '../providers/app_providers.dart';

class SubscriptionUpgradeDialog extends ConsumerStatefulWidget {
  final String? limitWarningTitle;
  final String? limitWarningMessage;

  const SubscriptionUpgradeDialog({
    Key? key,
    this.limitWarningTitle,
    this.limitWarningMessage,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    String? limitWarningTitle,
    String? limitWarningMessage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SubscriptionUpgradeDialog(
        limitWarningTitle: limitWarningTitle,
        limitWarningMessage: limitWarningMessage,
      ),
    );
  }

  @override
  ConsumerState<SubscriptionUpgradeDialog> createState() => _SubscriptionUpgradeDialogState();
}

class _SubscriptionUpgradeDialogState extends ConsumerState<SubscriptionUpgradeDialog> {
  late String _selectedPlanId;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final currentPlan = ref.read(authProvider).value?.subscriptionPlan ?? 'free';
    if (currentPlan.toLowerCase() == 'free') {
      _selectedPlanId = 'plan_1299'; // Default recommendation: 2-year value plan
    } else {
      _selectedPlanId = currentPlan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(authProvider).value;
    final currentPlanConfig = SubscriptionPlanConfig.getPlan(owner?.subscriptionPlan);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subscription Plans',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Current: ${currentPlanConfig.name}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Limit Warning Banner if present
          if (widget.limitWarningMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.alertRed, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.limitWarningTitle != null)
                          Text(
                            widget.limitWarningTitle!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.alertRed,
                            ),
                          ),
                        Text(
                          widget.limitWarningMessage!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Plan List
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                ...SubscriptionPlanConfig.allPlans.map((plan) {
                  final isSelected = _selectedPlanId == plan.id;
                  final isCurrent = currentPlanConfig.id == plan.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPlanId = plan.id;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (plan.price == 0 ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF))
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? (plan.price == 0 ? Colors.blueGrey : AppColors.primaryPill)
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryPill.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? AppColors.primaryPill : Colors.grey,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          plan.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.textMain,
                                          ),
                                        ),
                                        if (plan.isPopular) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFF59E0B)),
                                            ),
                                            child: const Text(
                                              'POPULAR',
                                              style: TextStyle(
                                                color: Color(0xFFB45309),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (plan.isBestValue) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF22C55E)),
                                            ),
                                            child: const Text(
                                              'BEST VALUE',
                                              style: TextStyle(
                                                color: Color(0xFF15803D),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (isCurrent) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0E7FF),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'CURRENT',
                                              style: TextStyle(
                                                color: Color(0xFF4338CA),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (plan.savingsText.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        plan.savingsText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: plan.price > 0 ? const Color(0xFF059669) : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                plan.price == 0 ? 'Free' : '₹${plan.price}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: plan.price == 0 ? Colors.blueGrey : AppColors.primaryPill,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Quota Badges Row
                          Row(
                            children: [
                              _buildQuotaPill(Icons.home_work_outlined, plan.propertiesDisplay),
                              const SizedBox(width: 8),
                              _buildQuotaPill(Icons.meeting_room_outlined, plan.roomsDisplay),
                              const SizedBox(width: 8),
                              _buildQuotaPill(Icons.people_alt_outlined, plan.guestsDisplay),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Key features list
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: plan.features.take(3).map((feat) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.verifiedGreen, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    feat,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Upgrade Button & Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUpdating
                        ? null
                        : () async {
                            final targetPlan = SubscriptionPlanConfig.getPlan(_selectedPlanId);
                            if (targetPlan.id == currentPlanConfig.id) {
                              Navigator.pop(context);
                              return;
                            }

                            // Plans are granted by the server after payment is confirmed;
                            // the app can no longer switch plans by itself (it used to
                            // write the plan straight to the database with no payment).
                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(context);
                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  targetPlan.price == 0
                                      ? 'To change your plan, please contact support.'
                                      : 'To activate ${targetPlan.name}, please contact support. '
                                          'Your plan is enabled on your account once payment is confirmed.',
                                ),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPill,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _selectedPlanId == currentPlanConfig.id
                                ? 'Keep Current Plan'
                                : _selectedPlanId == 'free'
                                    ? 'Contact support to change plan'
                                    : 'Request ${SubscriptionPlanConfig.getPlan(_selectedPlanId).name} (₹${SubscriptionPlanConfig.getPlan(_selectedPlanId).price})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlimited rooms & guests. Plans are activated on your account after payment is confirmed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMain),
          ),
        ],
      ),
    );
  }
}
