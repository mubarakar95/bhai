import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/indian_states.dart';
import '../../../core/models/models.dart';
import '../../../core/models/subscription_plan.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/widgets/replica_header_scaffold.dart';
import '../../../core/widgets/photo_crop_screen.dart';
import '../../../core/widgets/subscription_upgrade_dialog.dart';
import 'select_previous_guest_sheet.dart';

class AddGuestFlow extends ConsumerStatefulWidget {
  final String? initialPropertyId;
  final String? initialRoomId;
  final Person? initialPerson;

  const AddGuestFlow({
    Key? key,
    this.initialPropertyId,
    this.initialRoomId,
    this.initialPerson,
  }) : super(key: key);

  @override
  ConsumerState<AddGuestFlow> createState() => _AddGuestFlowState();
}

class _AddGuestFlowState extends ConsumerState<AddGuestFlow> {
  int _currentStep = 0;

  // --- Step 0: Aadhaar Verification State ---
  final _aadhaarController = TextEditingController();
  final _aadhaarFormKey = GlobalKey<FormState>();
  bool _isVerifyingAadhaar = false;
  bool _hasVerifiedAadhaar = false;
  Person? _existingPerson;
  Owner? _blacklistingOwner;
  GuestStayHistory? _activeStayInOtherProperty;
  bool _isNewPerson = true;

  // --- Step 1: Profile State ---
  final _profileFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _wifeNameController = TextEditingController();
  final _wifeMobileController = TextEditingController();
  final _policeController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  String _selectedState = 'Kerala';
  final _pincodeController = TextEditingController();
  DateTime? _dob;
  File? _personPhotoFile;
  File? _aadhaarPhotoFile;
  String? _uploadedPersonPhotoUrl;
  String? _uploadedAadhaarPhotoUrl;

  // --- Step 2: Room Allocation State ---
  final _allocationFormKey = GlobalKey<FormState>();
  final _rateController = TextEditingController(text: '0');
  String? _selectedPropertyId;
  String? _selectedRoomId;
  RentalBillingType _selectedBillingType = RentalBillingType.monthly;
  DateTime _checkInDate = DateTime.now();

  // --- Step 3: Initial Payment State ---
  final _paymentFormKey = GlobalKey<FormState>();
  final _paymentAmountController = TextEditingController(text: '0');
  final _paymentNotesController = TextEditingController();
  PaymentCategory _paymentType = PaymentCategory.advance;
  String _paymentMode = 'upi';

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedPropertyId = widget.initialPropertyId;
    _selectedRoomId = widget.initialRoomId;

    if (widget.initialPerson != null) {
      _populatePersonDetails(widget.initialPerson!);
    }

    if (_selectedPropertyId != null && _selectedRoomId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rooms = ref.read(roomsProvider(_selectedPropertyId!)).value ?? [];
        final match = rooms.where((r) => r.id == _selectedRoomId);
        if (match.isNotEmpty) {
          final room = match.first;
          if (mounted) {
            setState(() {
              if (_selectedBillingType == RentalBillingType.monthly) {
                _rateController.text = room.monthlyRate > 0
                    ? room.monthlyRate.toStringAsFixed(0)
                    : '0';
              } else if (_selectedBillingType == RentalBillingType.daily) {
                _rateController.text = room.dailyRate > 0
                    ? room.dailyRate.toStringAsFixed(0)
                    : '0';
              } else {
                _rateController.text = room.hourlyRate > 0
                    ? room.hourlyRate.toStringAsFixed(0)
                    : '0';
              }
            });
          }
        }
      });
    }
  }

  void _populatePersonDetails(Person person) {
    _existingPerson = person;
    _hasVerifiedAadhaar = true;
    _isNewPerson = false;
    _aadhaarController.text = person.aadhaarNo;
    _nameController.text = person.name;
    _mobileController.text = person.mobileNo;
    _fatherNameController.text = person.fatherName;
    _motherNameController.text = person.motherName ?? '';
    _wifeNameController.text = person.wifeName ?? '';
    _wifeMobileController.text = person.wifeMobileNo ?? '';
    _policeController.text = person.policeStationCircle;
    _addressController.text = person.address;
    _cityController.text = person.city;
    _selectedState = person.state.isNotEmpty && indianStatesAndUTs.contains(person.state)
        ? person.state
        : 'Kerala';
    _pincodeController.text = person.pincode;
    _dob = person.dob;
    _uploadedPersonPhotoUrl = person.personPhoto;
    _uploadedAadhaarPhotoUrl = person.aadhaarCardPhoto;

    // Directly jump to Room Allocation since KYC is already complete
    _currentStep = 2;
  }

  Future<void> _pickFromPreviousGuests() async {
    final person = await SelectPreviousGuestSheet.show(
      context,
      targetPropertyId: _selectedPropertyId,
      targetRoomId: _selectedRoomId,
    );
    if (person != null && mounted) {
      setState(() {
        _populatePersonDetails(person);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected past guest: ${person.name}. Please confirm room allocation.'),
          backgroundColor: AppColors.verifiedGreen,
        ),
      );
    }
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _wifeNameController.dispose();
    _wifeMobileController.dispose();
    _policeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _rateController.dispose();
    _paymentAmountController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }

  // --- Image Picking with Zoom & Crop ---
  Future<void> _pickImage(bool isPersonPhoto) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    cropShape: isPersonPhoto ? CropShape.circle : CropShape.rectangle,
                    title: isPersonPhoto ? 'Crop Guest Face Photo' : 'Crop Aadhaar Card',
                  );
                  if (file != null) {
                    setState(() {
                      if (isPersonPhoto) {
                        _personPhotoFile = file;
                      } else {
                        _aadhaarPhotoFile = file;
                      }
                    });
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
                    cropShape: isPersonPhoto ? CropShape.circle : CropShape.rectangle,
                    title: isPersonPhoto ? 'Crop Guest Face Photo' : 'Crop Aadhaar Card',
                  );
                  if (file != null) {
                    setState(() {
                      if (isPersonPhoto) {
                        _personPhotoFile = file;
                      } else {
                        _aadhaarPhotoFile = file;
                      }
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final Uri url = Uri.parse('tel:$clean');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer for $phoneNumber')),
        );
      }
    }
  }

  Widget _buildModalInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryPill),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMain),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _showBlacklistWarningModal(BuildContext context, Person person, Owner? owner) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.alertRed.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.dangerous_rounded, color: AppColors.alertRed, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'CRITICAL: BLACKLIST WARNING',
                style: TextStyle(
                  color: AppColors.alertRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${person.name} is currently flagged as BLACKLISTED in the database.',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.alertRed.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.alertRed.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.report_problem_rounded, color: AppColors.alertRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Reason: ${person.blacklistReason?.isNotEmpty == true ? person.blacklistReason! : "Violation of conduct standards / unpaid dues"}',
                            style: const TextStyle(
                              color: AppColors.alertRed,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.glassBorder),
                    _buildModalInfoRow(
                      Icons.person_pin_rounded,
                      'Blacklisted By',
                      owner != null && owner.fullName.isNotEmpty
                          ? '${owner.fullName}${owner.businessName != null && owner.businessName!.isNotEmpty ? " (${owner.businessName})" : ""}'
                          : 'Registered Landlord / User',
                    ),
                    const SizedBox(height: 8),
                    _buildModalInfoRow(
                      Icons.phone_in_talk_rounded,
                      'Landlord Contact',
                      owner != null && owner.mobileNo.isNotEmpty
                          ? owner.mobileNo
                          : 'Not available on file',
                    ),
                    if (owner != null && owner.mobileNo.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryPill,
                            side: const BorderSide(color: AppColors.primaryPill, width: 1.5),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () => _makeCall(owner.mobileNo),
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          label: Text(
                            'CALL LANDLORD (${owner.mobileNo})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    if (person.blacklistedAt != null) ...[
                      const SizedBox(height: 8),
                      _buildModalInfoRow(
                        Icons.calendar_month_rounded,
                        'Date Reported',
                        DateFormat('dd MMMM yyyy, hh:mm a').format(person.blacklistedAt!.toLocal()),
                      ),
                    ],
                    if (person.policeStationCircle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildModalInfoRow(
                        Icons.local_police_rounded,
                        'Police Circle',
                        person.policeStationCircle,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.amber.shade900, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note: This blacklist status can ONLY be removed by the original user (${owner?.fullName ?? "original landlord"}${owner != null && owner.mobileNo.isNotEmpty ? ", ${owner.mobileNo}" : ""}). Adding him will preserve his blacklisted status.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL / ABORT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ACKNOWLEDGE & PROCEED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
    return res == true;
  }

  // --- Step 0: Aadhaar Verification ---
  Future<void> _verifyAadhaar() async {
    FocusScope.of(context).unfocus();
    if (!_aadhaarFormKey.currentState!.validate()) return;
    final aadhaar = _aadhaarController.text.trim();

    setState(() {
      _isVerifyingAadhaar = true;
      _existingPerson = null;
      _blacklistingOwner = null;
      _activeStayInOtherProperty = null;
    });

    try {
      final db = ref.read(dbServiceProvider);
      final person = await db.searchGuestByAadhaar(aadhaar);

      GuestStayHistory? activeStay;
      Owner? blacklistingOwner;
      if (person != null) {
        activeStay = await db.getActiveStayForPerson(person.id);
        if (person.isBlacklisted) {
          final ownerId = person.blacklistedBy?.isNotEmpty == true
              ? person.blacklistedBy!
              : person.createdByOwnerId;
          blacklistingOwner = await db.getOwnerById(ownerId);
        }
      }

      setState(() {
        _hasVerifiedAadhaar = true;
        _existingPerson = person;
        _blacklistingOwner = blacklistingOwner;
        _activeStayInOtherProperty = activeStay;

        if (person != null) {
          _isNewPerson = false;
          _nameController.text = person.name;
          _mobileController.text = person.mobileNo;
          _fatherNameController.text = person.fatherName;
          _motherNameController.text = person.motherName ?? '';
          _wifeNameController.text = person.wifeName ?? '';
          _wifeMobileController.text = person.wifeMobileNo ?? '';
          _policeController.text = person.policeStationCircle;
          _addressController.text = person.address;
          _cityController.text = person.city;
          _selectedState = person.state.isNotEmpty && indianStatesAndUTs.contains(person.state)
              ? person.state
              : 'Kerala';
          _pincodeController.text = person.pincode;
          _dob = person.dob;
          _uploadedPersonPhotoUrl = person.personPhoto;
          _uploadedAadhaarPhotoUrl = person.aadhaarCardPhoto;
        } else {
          _isNewPerson = true;
          _nameController.clear();
          _mobileController.clear();
          _fatherNameController.clear();
          _motherNameController.clear();
          _wifeNameController.clear();
          _wifeMobileController.clear();
          _policeController.clear();
          _addressController.clear();
          _cityController.clear();
          _selectedState = 'Kerala';
          _pincodeController.clear();
          _dob = null;
          _personPhotoFile = null;
          _aadhaarPhotoFile = null;
          _uploadedPersonPhotoUrl = null;
          _uploadedAadhaarPhotoUrl = null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aadhaar verification error: $e'), backgroundColor: AppColors.alertRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifyingAadhaar = false);
      }
    }
  }

  void _proceedToProfileStep() async {
    if (!_hasVerifiedAadhaar) {
      await _verifyAadhaar();
      return;
    }

    if (_existingPerson != null && _existingPerson!.isBlacklisted) {
      if (_blacklistingOwner == null) {
        final db = ref.read(dbServiceProvider);
        final ownerId = _existingPerson!.blacklistedBy?.isNotEmpty == true
            ? _existingPerson!.blacklistedBy!
            : _existingPerson!.createdByOwnerId;
        _blacklistingOwner = await db.getOwnerById(ownerId);
      }
      final proceed = await _showBlacklistWarningModal(context, _existingPerson!, _blacklistingOwner);
      if (!proceed) return;
    }

    setState(() => _currentStep = 1);
  }

  // --- Step 1 -> Step 2 ---
  Future<void> _proceedToAllocationStep() async {
    if (_isNewPerson) {
      if (!_profileFormKey.currentState!.validate()) return;
      if (_dob == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select Date of Birth.')),
        );
        return;
      }
      if (_personPhotoFile == null && (_uploadedPersonPhotoUrl == null || _uploadedPersonPhotoUrl!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guest face photo is required for official identity registration.')),
        );
        return;
      }
    } else {
      if (!_profileFormKey.currentState!.validate()) return;
    }

    // Check if the mobile number or Aadhaar is flagged in the safety pool
    final db = ref.read(dbServiceProvider);
    final blacklistMatch = _existingPerson?.isBlacklisted == true
        ? _existingPerson
        : await db.checkIfBlacklisted(
            aadhaar: _aadhaarController.text.trim(),
            mobile: _mobileController.text.trim(),
          );

    if (blacklistMatch != null && blacklistMatch.isBlacklisted) {
      if (_blacklistingOwner == null) {
        final ownerId = blacklistMatch.blacklistedBy?.isNotEmpty == true
            ? blacklistMatch.blacklistedBy!
            : blacklistMatch.createdByOwnerId;
        _blacklistingOwner = await db.getOwnerById(ownerId);
      }
      if (!mounted) return;
      final proceed = await _showBlacklistWarningModal(context, blacklistMatch, _blacklistingOwner);
      if (!proceed) return;
    }

    setState(() => _currentStep = 2);
  }

  // --- Step 2 -> Step 3 ---
  void _proceedToPaymentStep() {
    if (!_allocationFormKey.currentState!.validate()) return;
    if (_selectedPropertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a property.')),
      );
      return;
    }
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room.')),
      );
      return;
    }

    // Check room capacity
    final rooms = ref.read(roomsProvider(_selectedPropertyId!)).value ?? [];
    final match = rooms.where((r) => r.id == _selectedRoomId);
    if (match.isNotEmpty) {
      final room = match.first;
      if (room.currentOccupancy >= room.capacity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected Room is already FULL. Please choose another room.')),
        );
        return;
      }
    }

    if (_paymentAmountController.text.trim().isEmpty) {
      _paymentAmountController.text = '0';
    }

    setState(() => _currentStep = 3);
  }

  // --- Final Submit Check-In ---
  Future<void> _submitAll() async {
    if (!_paymentFormKey.currentState!.validate()) return;

    final currentOwner = ref.read(authProvider).value;
    final staysState = ref.read(staysProvider);
    final activeGuestsCount = staysState.value?.where((s) => s.status == 'active').length ?? 0;

    // Check capacity limit (Free Tier: 20 people)
    final guestLimitCheck = SubscriptionPlanConfig.checkCanAddGuest(
      owner: currentOwner,
      currentActiveGuestsCount: activeGuestsCount,
    );
    if (!guestLimitCheck.canAdd) {
      SubscriptionUpgradeDialog.show(
        context,
        limitWarningTitle: 'Guest Capacity Reached (Free Tier: 20 People)',
        limitWarningMessage: guestLimitCheck.reason,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final db = ref.read(dbServiceProvider);
      final ownerId = currentOwner?.id ?? db.currentOwnerId;
      if (ownerId == null || ownerId.isEmpty) {
        throw Exception('Please sign in again to continue.');
      }

      // 1. Upload photos if newly picked (resilient fallback to local path if storage fails)
      if (_personPhotoFile != null) {
        try {
          _uploadedPersonPhotoUrl = await db.uploadImage('person-photos', _personPhotoFile!);
        } catch (e) {
          debugPrint('Person photo upload fallback: $e');
          _uploadedPersonPhotoUrl = _personPhotoFile!.path;
        }
      }
      if (_aadhaarPhotoFile != null) {
        try {
          _uploadedAadhaarPhotoUrl = await db.uploadImage('aadhaar-photos', _aadhaarPhotoFile!);
        } catch (e) {
          debugPrint('Aadhaar photo upload fallback: $e');
          _uploadedAadhaarPhotoUrl = _aadhaarPhotoFile!.path;
        }
      }

      // Check if person is already blacklisted in DB/cache by Aadhaar or Mobile
      final blacklistMatch = _existingPerson?.isBlacklisted == true
          ? _existingPerson
          : await db.checkIfBlacklisted(
              aadhaar: _aadhaarController.text.trim(),
              mobile: _mobileController.text.trim(),
            );

      if (blacklistMatch != null && blacklistMatch.isBlacklisted) {
        if (_blacklistingOwner == null) {
          final ownerId = blacklistMatch.blacklistedBy?.isNotEmpty == true
              ? blacklistMatch.blacklistedBy!
              : blacklistMatch.createdByOwnerId;
          _blacklistingOwner = await db.getOwnerById(ownerId);
        }
        final proceed = await _showBlacklistWarningModal(context, blacklistMatch, _blacklistingOwner);
        if (!proceed) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // 2. Create or reuse Person (preserving blacklist status!)
      Person finalPerson;
      if (_isNewPerson || _existingPerson == null) {
        final newPerson = Person(
          id: blacklistMatch?.id ?? '',
          name: _nameController.text.trim(),
          mobileNo: _mobileController.text.trim(),
          aadhaarNo: _aadhaarController.text.trim(),
          fatherName: _fatherNameController.text.trim(),
          motherName: _motherNameController.text.trim().isEmpty ? null : _motherNameController.text.trim(),
          wifeName: _wifeNameController.text.trim().isEmpty ? null : _wifeNameController.text.trim(),
          wifeMobileNo: _wifeMobileController.text.trim().isEmpty ? null : _wifeMobileController.text.trim(),
          policeStationCircle: _policeController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          state: _selectedState,
          pincode: _pincodeController.text.trim(),
          dob: _dob ?? DateTime(1995, 1, 1),
          personPhoto: _uploadedPersonPhotoUrl ?? '',
          aadhaarCardPhoto: _uploadedAadhaarPhotoUrl,
          isBlacklisted: blacklistMatch?.isBlacklisted ?? false,
          blacklistReason: blacklistMatch?.blacklistReason,
          blacklistedBy: blacklistMatch?.blacklistedBy,
          blacklistedAt: blacklistMatch?.blacklistedAt,
          createdByOwnerId: blacklistMatch?.createdByOwnerId.isNotEmpty == true ? blacklistMatch!.createdByOwnerId : ownerId,
          createdAt: blacklistMatch?.createdAt ?? DateTime.now(),
        );
        finalPerson = await db.addGuest(newPerson);
      } else {
        final updatedPerson = Person(
          id: _existingPerson!.id,
          name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : _existingPerson!.name,
          mobileNo: _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : _existingPerson!.mobileNo,
          aadhaarNo: _aadhaarController.text.trim().isNotEmpty ? _aadhaarController.text.trim() : _existingPerson!.aadhaarNo,
          fatherName: _fatherNameController.text.trim().isNotEmpty ? _fatherNameController.text.trim() : _existingPerson!.fatherName,
          motherName: _motherNameController.text.trim().isNotEmpty ? _motherNameController.text.trim() : _existingPerson!.motherName,
          wifeName: _wifeNameController.text.trim().isNotEmpty ? _wifeNameController.text.trim() : _existingPerson!.wifeName,
          wifeMobileNo: _wifeMobileController.text.trim().isNotEmpty ? _wifeMobileController.text.trim() : _existingPerson!.wifeMobileNo,
          policeStationCircle: _policeController.text.trim().isNotEmpty ? _policeController.text.trim() : _existingPerson!.policeStationCircle,
          address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : _existingPerson!.address,
          city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : _existingPerson!.city,
          state: _selectedState.isNotEmpty ? _selectedState : _existingPerson!.state,
          pincode: _pincodeController.text.trim().isNotEmpty ? _pincodeController.text.trim() : _existingPerson!.pincode,
          dob: _dob ?? _existingPerson!.dob,
          personPhoto: _uploadedPersonPhotoUrl ?? _existingPerson!.personPhoto,
          aadhaarCardPhoto: _uploadedAadhaarPhotoUrl ?? _existingPerson!.aadhaarCardPhoto,
          isBlacklisted: _existingPerson!.isBlacklisted,
          blacklistReason: _existingPerson!.blacklistReason,
          blacklistedBy: _existingPerson!.blacklistedBy,
          blacklistedAt: _existingPerson!.blacklistedAt,
          createdByOwnerId: _existingPerson!.createdByOwnerId.isNotEmpty ? _existingPerson!.createdByOwnerId : ownerId,
          createdAt: _existingPerson!.createdAt,
        );
        finalPerson = await db.addGuest(updatedPerson);
      }

      // 3. Create Stay record
      final rate = double.tryParse(_rateController.text) ?? 0.0;
      final newStay = Stay(
        id: '',
        personId: finalPerson.id,
        roomId: _selectedRoomId!,
        propertyId: _selectedPropertyId!,
        ownerId: ownerId,
        checkInDate: _checkInDate,
        rentalTypeUsed: _selectedBillingType,
        agreedRate: rate,
        status: 'active',
        createdAt: DateTime.now(),
      );
      final savedStay = await db.addStay(newStay);

      // 4. Record Initial Payment (if amount > 0)
      final payVal = _paymentAmountController.text.trim();
      if (payVal.isNotEmpty) {
        final amount = double.tryParse(payVal) ?? 0.0;
        if (amount > 0) {
          final payment = Payment(
            id: '',
            stayId: savedStay.id,
            personId: finalPerson.id,
            ownerId: ownerId,
            paymentType: _paymentType,
            amount: amount,
            paymentMode: _paymentMode,
            paidAt: _checkInDate,
            notes: _paymentNotesController.text.trim().isEmpty
                ? 'Initial Check-in payment'
                : _paymentNotesController.text.trim(),
            recordedBy: ownerId,
            createdAt: DateTime.now(),
          );
          await db.addPayment(payment);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest registered and checked in successfully!'),
            backgroundColor: AppColors.verifiedGreen,
          ),
        );
        ref.invalidate(staysProvider);
        if (_selectedPropertyId != null) {
          ref.invalidate(roomsProvider(_selectedPropertyId!));
        }
        ref.invalidate(propertiesProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete check-in: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // --- UI Step Indicator ---
  Widget _buildStepIndicator() {
    final steps = [
      {'icon': Icons.fingerprint_rounded, 'label': 'Aadhaar'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
      {'icon': Icons.meeting_room_rounded, 'label': 'Room'},
      {'icon': Icons.payments_rounded, 'label': 'Payment'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glassCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (idx) {
          final isPassed = _currentStep > idx;
          final isCurrent = _currentStep == idx;
          final color = isCurrent
              ? AppColors.primaryPill
              : (isPassed ? AppColors.verifiedGreen : AppColors.textSecondary.withOpacity(0.5));

          return Expanded(
            child: InkWell(
              onTap: isPassed ? () => setState(() => _currentStep = idx) : null,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCurrent || isPassed ? color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Center(
                      child: isPassed
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : Icon(
                              steps[idx]['icon'] as IconData,
                              color: isCurrent ? Colors.white : color,
                              size: 16,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      steps[idx]['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isCurrent ? AppColors.textMain : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- Step 0 UI: Aadhaar Lookup ---
  Widget _buildStep0Aadhaar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.glassCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Form(
              key: _aadhaarFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryPill,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aadhaar Identity Lookup',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Official identity verification check for tenant and guest registration.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _aadhaarController,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    decoration: InputDecoration(
                      labelText: 'Guest Aadhaar Number *',
                      hintText: 'Enter 12-digit UID',
                      prefixIcon: const Icon(Icons.credit_card_rounded),
                      suffixIcon: _aadhaarController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                setState(() {
                                  _aadhaarController.clear();
                                  _hasVerifiedAadhaar = false;
                                  _existingPerson = null;
                                  _activeStayInOtherProperty = null;
                                });
                              },
                            )
                          : null,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length != 12) return 'Aadhaar must be exactly 12 digits';
                      if (int.tryParse(v.trim()) == null) return 'Aadhaar must contain only numbers';
                      return null;
                    },
                    onChanged: (v) {
                      if (_hasVerifiedAadhaar) {
                        setState(() => _hasVerifiedAadhaar = false);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPill,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isVerifyingAadhaar ? null : _verifyAadhaar,
                      icon: _isVerifyingAadhaar
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded, size: 20),
                      label: Text(
                        _isVerifyingAadhaar ? 'SCANNING SYSTEM...' : 'VERIFY AADHAAR',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_hasVerifiedAadhaar) ...[
            const SizedBox(height: 18),
            Row(
              children: const [
                Expanded(child: Divider(color: AppColors.glassBorder)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('OR', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Expanded(child: Divider(color: AppColors.glassBorder)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: const BorderSide(color: AppColors.primaryPill, width: 1.5),
                  backgroundColor: AppColors.primaryPill.withOpacity(0.06),
                ),
                icon: const Icon(Icons.history_rounded, color: AppColors.primaryPill, size: 20),
                label: const Text(
                  'Choose from Previous / Checked-Out Guests',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPill, fontSize: 13.5),
                ),
                onPressed: _pickFromPreviousGuests,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Security & Verification Result Card
          if (_hasVerifiedAadhaar) ...[
            // 1. Blacklist Alert
            if (_existingPerson != null && _existingPerson!.isBlacklisted) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.alertRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.alertRed, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.dangerous_rounded, color: AppColors.alertRed, size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'CRITICAL WARNING: BLACKLISTED GUEST',
                            style: TextStyle(
                              color: AppColors.alertRed,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This individual has been reported as BLACKLISTED across the landlord safety pool.\n\n'
                      '• Reason: ${_existingPerson!.blacklistReason?.isNotEmpty == true ? _existingPerson!.blacklistReason! : "Violation of conduct standards / unpaid dues"}\n'
                      '• Flagged By: ${_blacklistingOwner != null && _blacklistingOwner!.fullName.isNotEmpty ? _blacklistingOwner!.fullName : "Original Landlord"}${_blacklistingOwner?.businessName?.isNotEmpty == true ? " (${_blacklistingOwner!.businessName})" : ""}\n'
                      '• Landlord Phone: ${_blacklistingOwner?.mobileNo.isNotEmpty == true ? _blacklistingOwner!.mobileNo : "Contact on record"}\n'
                      '• Origin Police Circle: ${_existingPerson!.policeStationCircle.isNotEmpty ? _existingPerson!.policeStationCircle : "Not Specified"}\n'
                      '• Reported Date: ${_existingPerson!.blacklistedAt != null ? DateFormat('dd MMM yyyy').format(_existingPerson!.blacklistedAt!.toLocal()) : "Documented"}',
                      style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textMain),
                    ),
                    if (_blacklistingOwner != null && _blacklistingOwner!.mobileNo.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.alertRed,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          onPressed: () => _makeCall(_blacklistingOwner!.mobileNo),
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                          label: Text(
                            'CALL LANDLORD (${_blacklistingOwner!.mobileNo})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 2. Active Stay in Another Property Alert
            if (_activeStayInOtherProperty != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.orange.shade800, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade900, size: 28),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'ACTIVE STAY DETECTED IN ANOTHER PROPERTY',
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_existingPerson?.name ?? "This guest"} is currently registered with an active stay at:\n'
                      '• Property: ${_activeStayInOtherProperty!.propertyName} (${_activeStayInOtherProperty!.propertyCity})\n'
                      '• Room: ${_activeStayInOtherProperty!.roomNumber}\n'
                      '• Checked-In: ${DateFormat("dd MMM yyyy").format(_activeStayInOtherProperty!.checkInDate)}\n\n'
                      'Please verify if the guest officially checked out or left without informing the previous owner.',
                      style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textMain),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 3. Status Summary Card (Existing vs New)
            if (_existingPerson != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.verifiedBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.verifiedGreen.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.verifiedGreen.withOpacity(0.2),
                      backgroundImage: AppImageHelper.getImageProvider(_existingPerson!.personPhoto),
                      child: AppImageHelper.getImageProvider(_existingPerson!.personPhoto) == null
                          ? const Icon(Icons.person_rounded, color: AppColors.verifiedGreen, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.check_circle_rounded, color: AppColors.verifiedGreen, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'EXISTING GUEST FOUND',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.verifiedGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _existingPerson!.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Mobile: ${_existingPerson!.mobileNo} • ${_existingPerson!.city}, ${_existingPerson!.state}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.brandBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, color: AppColors.brandBlue, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NEW GUEST REGISTRATION',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No prior record found for Aadhaar ${_aadhaarController.text.trim()}. Proceed to capture photo and guest identity details.',
                            style: const TextStyle(fontSize: 13, color: AppColors.textMain),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPill,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _proceedToProfileStep,
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text(
                  'PROCEED TO GUEST DETAILS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Step 1 UI: Profile & Documents ---
  Widget _buildStep1Profile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photos Section with Zoom & Crop
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.glassCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IDENTITY PHOTOS (WITH ZOOM & CROP)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.primaryPill,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Face Photo
                      Expanded(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _pickImage(true),
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.neutralPill,
                                  border: Border.all(color: AppColors.primaryPill, width: 2),
                                  image: _personPhotoFile != null
                                      ? DecorationImage(image: FileImage(_personPhotoFile!), fit: BoxFit.cover)
                                      : (_uploadedPersonPhotoUrl != null && _uploadedPersonPhotoUrl!.isNotEmpty
                                          ? (() {
                                              final prov = AppImageHelper.getImageProvider(_uploadedPersonPhotoUrl!);
                                              return prov != null ? DecorationImage(image: prov, fit: BoxFit.cover) : null;
                                            })()
                                          : null),
                                ),
                                child: (_personPhotoFile == null &&
                                        (_uploadedPersonPhotoUrl == null || _uploadedPersonPhotoUrl!.isEmpty))
                                    ? const Icon(Icons.add_a_photo_rounded, color: AppColors.primaryPill, size: 30)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text('Face Photo *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () => _pickImage(true),
                              child: const Text('Crop / Change', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),

                      // Aadhaar Photo
                      Expanded(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _pickImage(false),
                              child: Container(
                                width: 110,
                                height: 75,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppColors.neutralPill,
                                  border: Border.all(color: AppColors.primaryPill, width: 2),
                                  image: _aadhaarPhotoFile != null
                                      ? DecorationImage(image: FileImage(_aadhaarPhotoFile!), fit: BoxFit.cover)
                                      : (_uploadedAadhaarPhotoUrl != null && _uploadedAadhaarPhotoUrl!.isNotEmpty
                                          ? (() {
                                              final prov = AppImageHelper.getImageProvider(_uploadedAadhaarPhotoUrl!);
                                              return prov != null ? DecorationImage(image: prov, fit: BoxFit.cover) : null;
                                            })()
                                          : null),
                                ),
                                child: (_aadhaarPhotoFile == null &&
                                        (_uploadedAadhaarPhotoUrl == null || _uploadedAadhaarPhotoUrl!.isEmpty))
                                    ? const Icon(Icons.document_scanner_rounded,
                                        color: AppColors.primaryPill, size: 28)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text('Aadhaar Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () => _pickImage(false),
                              child: const Text('Crop / Change', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Profile Fields
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.glassCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERSONAL INFORMATION',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.primaryPill,
                        ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_rounded)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Mobile Number *', prefixIcon: Icon(Icons.phone_rounded)),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().replaceAll(RegExp(r'\D'), '').length != 10) {
                        return 'Must be 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Date of Birth Picker
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.glassBorder),
                    ),
                    leading: const Icon(Icons.cake_rounded, color: AppColors.primaryPill),
                    title: Text(
                      _dob == null ? 'Date of Birth *' : 'DOB: ${DateFormat('dd MMM yyyy').format(_dob!)}',
                      style: TextStyle(
                        fontWeight: _dob != null ? FontWeight.bold : FontWeight.normal,
                        color: _dob != null ? AppColors.textMain : AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dob ?? DateTime(1995, 1, 1),
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now().subtract(const Duration(days: 365 * 14)),
                      );
                      if (picked != null) {
                        setState(() => _dob = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _fatherNameController,
                    decoration: const InputDecoration(
                        labelText: "Father's Full Name *", prefixIcon: Icon(Icons.family_restroom_rounded)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _motherNameController,
                    decoration: const InputDecoration(
                        labelText: "Mother's Name (Optional)", prefixIcon: Icon(Icons.person_outline_rounded)),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _wifeNameController,
                    decoration: const InputDecoration(
                      labelText: "Spouse Name (Optional)",
                      prefixIcon: Icon(Icons.favorite_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _wifeMobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Spouse Mobile Number (Optional)",
                      prefixIcon: Icon(Icons.phone_iphone_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _policeController,
                    decoration: const InputDecoration(
                      labelText: 'Home Police Station / Circle *',
                      hintText: 'e.g. Murshidabad PS / Patna PS',
                      prefixIcon: Icon(Icons.local_police_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required for police registry' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                        labelText: 'Permanent Address *', prefixIcon: Icon(Icons.home_rounded)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                        labelText: 'City / District *', prefixIcon: Icon(Icons.location_city_rounded)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedState,
                    items: indianStatesAndUTs
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedState = val);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Home State *',
                      prefixIcon: Icon(Icons.map_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Pincode *', prefixIcon: Icon(Icons.pin_drop_rounded)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 1 Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => setState(() => _currentStep = 0),
                    child: const Text('BACK'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPill,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _proceedToAllocationStep,
                    child: const Text('ROOM ALLOCATION ->', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- Step 2 UI: Room Allocation ---
  Widget _buildStep2Allocation() {
    final properties = ref.watch(propertiesProvider).value ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Form(
        key: _allocationFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Guest summary banner showing who is being allocated
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryPill.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primaryPill.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryPill.withOpacity(0.15),
                    backgroundImage: AppImageHelper.getImageProvider(_uploadedPersonPhotoUrl),
                    child: _uploadedPersonPhotoUrl == null || _uploadedPersonPhotoUrl!.isEmpty
                        ? Text(
                            _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'G',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPill, fontSize: 16),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.isNotEmpty ? _nameController.text : 'New Guest',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_mobileController.text.isNotEmpty ? _mobileController.text : "No phone"} • ${_aadhaarController.text.isNotEmpty ? "UID: ${_aadhaarController.text}" : "KYC Verified"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!_isNewPerson)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.verifiedGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'SAVED KYC',
                        style: TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.glassCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT PROPERTY & ROOM',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.primaryPill,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Property Dropdown
                  if (properties.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.alertRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'No properties found. Please add a property first from the Properties tab.',
                        style: TextStyle(color: AppColors.alertRed, fontSize: 13),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedPropertyId,
                      hint: const Text('Select Property *'),
                      items: properties
                          .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} (${p.city})', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPropertyId = val;
                          _selectedRoomId = null;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Property *',
                        prefixIcon: Icon(Icons.apartment_rounded),
                      ),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  const SizedBox(height: 14),

                  // Room Dropdown
                  if (_selectedPropertyId != null) ...[
                    Consumer(
                      builder: (context, ref, child) {
                        final roomsAsync = ref.watch(roomsProvider(_selectedPropertyId!));
                        return roomsAsync.when(
                          data: (rooms) {
                            if (rooms.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'No rooms registered under this property yet. Please add rooms in Property settings.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              );
                            }

                            return DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedRoomId,
                              hint: const Text('Select Room *'),
                              items: rooms.map((r) {
                                final isFull = r.currentOccupancy >= r.capacity;
                                return DropdownMenuItem(
                                  value: r.id,
                                  enabled: !isFull,
                                  child: Text(
                                    '${r.roomNumber} (${r.currentOccupancy}/${r.capacity} beds)${isFull ? " - FULL" : ""}',
                                    style: TextStyle(
                                      color: isFull ? Colors.grey : AppColors.textMain,
                                      fontWeight: isFull ? FontWeight.normal : FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedRoomId = val;
                                  final match = rooms.where((r) => r.id == val);
                                  if (match.isNotEmpty) {
                                    final room = match.first;
                                    if (_selectedBillingType == RentalBillingType.monthly) {
                                      _rateController.text = room.monthlyRate > 0
                                          ? room.monthlyRate.toStringAsFixed(0)
                                          : '0';
                                    } else if (_selectedBillingType == RentalBillingType.daily) {
                                      _rateController.text = room.dailyRate > 0
                                          ? room.dailyRate.toStringAsFixed(0)
                                          : '0';
                                    } else {
                                      _rateController.text = room.hourlyRate > 0
                                          ? room.hourlyRate.toStringAsFixed(0)
                                          : '0';
                                    }
                                  }
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Room Number *',
                                prefixIcon: Icon(Icons.meeting_room_rounded),
                              ),
                              validator: (v) => v == null ? 'Required' : null,
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, s) => Text('Error loading rooms: $e'),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Rental Billing Type
                  DropdownButtonFormField<RentalBillingType>(
                    isExpanded: true,
                    value: _selectedBillingType,
                    items: const [
                      DropdownMenuItem(value: RentalBillingType.monthly, child: Text('Monthly Rate')),
                      DropdownMenuItem(value: RentalBillingType.daily, child: Text('Daily Rate')),
                      DropdownMenuItem(value: RentalBillingType.hourly, child: Text('Hourly Rate')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedBillingType = val;
                          if (_selectedRoomId != null) {
                            if (_selectedPropertyId != null) {
                              final rooms = ref.read(roomsProvider(_selectedPropertyId!)).value ?? [];
                              final match = rooms.where((r) => r.id == _selectedRoomId);
                              if (match.isNotEmpty) {
                                final room = match.first;
                                if (_selectedBillingType == RentalBillingType.monthly) {
                                  _rateController.text = room.monthlyRate > 0
                                      ? room.monthlyRate.toStringAsFixed(0)
                                      : '0';
                                } else if (_selectedBillingType == RentalBillingType.daily) {
                                  _rateController.text = room.dailyRate > 0
                                      ? room.dailyRate.toStringAsFixed(0)
                                      : '0';
                                } else {
                                  _rateController.text = room.hourlyRate > 0
                                      ? room.hourlyRate.toStringAsFixed(0)
                                      : '0';
                                }
                              }
                            }
                          }
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Billing Mode *',
                      prefixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _rateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Agreed Rate (₹) *',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Check-in Date Picker
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.glassBorder),
                    ),
                    leading: const Icon(Icons.login_rounded, color: AppColors.primaryPill),
                    title: Text(
                      'Check-In Date: ${DateFormat('dd MMM yyyy').format(_checkInDate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                    onTap: () async {
                      final now = DateTime.now();
                      final firstDate = DateTime(2000, 1, 1);
                      final lastDate = now.add(const Duration(days: 365 * 2));
                      final initialDate = _checkInDate.isBefore(firstDate)
                          ? firstDate
                          : (_checkInDate.isAfter(lastDate) ? lastDate : _checkInDate);

                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: firstDate,
                        lastDate: lastDate,
                        helpText: 'Select Check-in Date',
                      );
                      if (picked != null) {
                        setState(() {
                          _checkInDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            now.hour,
                            now.minute,
                            now.second,
                          );
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 2 Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => setState(() => _currentStep = 1),
                    child: const Text('BACK'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPill,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _proceedToPaymentStep,
                    child: const Text('INITIAL PAYMENT ->', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- Step 3 UI: Initial Payment & Final Check-In ---
  Widget _buildStep3Payment() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Form(
        key: _paymentFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Guest summary banner showing who is being allocated
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryPill.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primaryPill.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryPill.withOpacity(0.15),
                    backgroundImage: AppImageHelper.getImageProvider(_uploadedPersonPhotoUrl),
                    child: _uploadedPersonPhotoUrl == null || _uploadedPersonPhotoUrl!.isEmpty
                        ? Text(
                            _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'G',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPill, fontSize: 16),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.isNotEmpty ? _nameController.text : 'New Guest',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_mobileController.text.isNotEmpty ? _mobileController.text : "No phone"} • ${_aadhaarController.text.isNotEmpty ? "UID: ${_aadhaarController.text}" : "KYC Verified"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!_isNewPerson)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.verifiedGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'SAVED KYC',
                        style: TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.glassCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INITIAL CHECK-IN PAYMENT (OPTIONAL)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.primaryPill,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Record any customer advance payment, deposit, or rent collected at check-in time. Default is ₹0.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<PaymentCategory>(
                    isExpanded: true,
                    value: _paymentType,
                    items: const [
                      DropdownMenuItem(value: PaymentCategory.advance, child: Text('Advance Rent')),
                      DropdownMenuItem(value: PaymentCategory.deposit, child: Text('Security Deposit')),
                      DropdownMenuItem(value: PaymentCategory.rent, child: Text('Standard Rent')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _paymentType = val);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Payment Category',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _paymentAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Customer Advance Payment (₹)',
                      hintText: 'Default 0 (leave 0 if paying later)',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _paymentMode,
                    items: const [
                      DropdownMenuItem(value: 'upi', child: Text('UPI / GooglePay / PhonePe')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash in Hand')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer / NEFT')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _paymentMode = val);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _paymentNotesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks',
                      hintText: 'e.g. Paid ₹3000 advance via GPay',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Step 3 Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () => setState(() => _currentStep = 2),
                    child: const Text('BACK'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.verifiedGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: _isSubmitting ? null : _submitAll,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(
                      _isSubmitting ? 'REGISTERING...' : 'COMPLETE & CHECK IN',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _handleBackStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackStep();
      },
      child: ReplicaHeaderScaffold(
        title: 'Guest Check-In Ledger',
        showBackButton: true,
        onBackPressed: _handleBackStep,
        body: Column(
          children: [
            // Step Progress Bar
            _buildStepIndicator(),

            // Active Step View
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  _buildStep0Aadhaar(),
                  _buildStep1Profile(),
                  _buildStep2Allocation(),
                  _buildStep3Payment(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
