import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/phone_helper.dart';

class UpdatePhoneNumberScreen extends ConsumerStatefulWidget {
  const UpdatePhoneNumberScreen({super.key});

  @override
  ConsumerState<UpdatePhoneNumberScreen> createState() => _UpdatePhoneNumberScreenState();
}

class _UpdatePhoneNumberScreenState extends ConsumerState<UpdatePhoneNumberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _submit(String ownerName) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clean = PhoneHelper.cleanPhoneNumber(_mobileController.text.trim());
      final error = await ref.read(authProvider.notifier).updateProfile(
            mobileNo: clean,
          );

      if (error != null && mounted) {
        setState(() {
          _errorMessage = error;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mobile number updated successfully! Welcome to Bhai App.'),
            backgroundColor: AppColors.verifiedGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final owner = authState.value;
    final fullName = owner?.fullName.isNotEmpty == true ? owner!.fullName : 'Property Owner';
    final email = owner?.email ?? '';
    final currentPlaceholder = owner?.mobileNo ?? '';

    return Container(
      decoration: AppColors.backgroundGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          automaticallyImplyLeading: false,
          actions: [
            TextButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      await ref.read(authProvider.notifier).logout();
                    },
              icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.textSecondary),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                color: AppColors.glassCard,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.glassBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 28,
                    spreadRadius: 0,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon Header
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F347AE2),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.phone_iphone_rounded,
                          color: AppColors.primaryPill,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      'Action Required',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFD97706),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Update Mobile Number',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMain,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Explanation
                    Text(
                      'Welcome $fullName! Your account was migrated from our legacy system with a temporary placeholder number. Please provide your active mobile number to complete your registration and continue.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Placeholder Badge
                    if (currentPlaceholder.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Temporary placeholder: $currentPlaceholder',
                                style: const TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Error Alert Box
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.alertBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.alertRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.alertRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.alertRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Mobile Number Input Field
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Your 10-Digit Mobile Number',
                        hintText: '9876543210',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone_rounded, size: 20, color: AppColors.primaryPill),
                              const SizedBox(width: 6),
                              const Text(
                                '+91',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(width: 1, height: 20, color: AppColors.divider),
                            ],
                          ),
                        ),
                        suffixIcon: _mobileController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _mobileController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        } else {
                          setState(() {});
                        }
                      },
                      validator: PhoneHelper.validateMobileNumber,
                    ),
                    const SizedBox(height: 24),

                    // Primary Submit Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _submit(fullName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPill,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Text(
                                'Save & Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Current Account Footer Info
                    if (email.isNotEmpty)
                      Center(
                        child: Text(
                          'Signed in as $email',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
