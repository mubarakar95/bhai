import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/indian_states.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/widgets/replica_header_scaffold.dart';
import '../../../core/widgets/photo_crop_screen.dart';

class EditGuestScreen extends ConsumerStatefulWidget {
  final Person guest;

  const EditGuestScreen({Key? key, required this.guest}) : super(key: key);

  @override
  ConsumerState<EditGuestScreen> createState() => _EditGuestScreenState();
}

class _EditGuestScreenState extends ConsumerState<EditGuestScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _fatherNameController;
  late TextEditingController _policeController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;

  File? _personPhotoFile;
  File? _aadhaarPhotoFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.guest.name);
    _mobileController = TextEditingController(text: widget.guest.mobileNo);
    _fatherNameController = TextEditingController(text: widget.guest.fatherName);
    _policeController = TextEditingController(text: widget.guest.policeStationCircle);
    _addressController = TextEditingController(text: widget.guest.address);
    _cityController = TextEditingController(text: widget.guest.city);
    _stateController = TextEditingController(text: widget.guest.state);
    _pincodeController = TextEditingController(text: widget.guest.pincode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _fatherNameController.dispose();
    _policeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final db = SupabaseService.instance;
      String personPhotoUrl = widget.guest.personPhoto;
      String? aadhaarPhotoUrl = widget.guest.aadhaarCardPhoto;

      if (_personPhotoFile != null) {
        try {
          personPhotoUrl = await db.uploadImage('person-photos', _personPhotoFile!);
        } catch (e) {
          personPhotoUrl = _personPhotoFile!.path;
        }
      }
      if (_aadhaarPhotoFile != null) {
        try {
          aadhaarPhotoUrl = await db.uploadImage('aadhaar-photos', _aadhaarPhotoFile!);
        } catch (e) {
          aadhaarPhotoUrl = _aadhaarPhotoFile!.path;
        }
      }

      final updatedGuest = Person(
        id: widget.guest.id,
        name: _nameController.text.trim(),
        mobileNo: _mobileController.text.trim(),
        aadhaarNo: widget.guest.aadhaarNo,
        fatherName: _fatherNameController.text.trim(),
        motherName: widget.guest.motherName,
        wifeName: widget.guest.wifeName,
        wifeMobileNo: widget.guest.wifeMobileNo,
        policeStationCircle: _policeController.text.trim(),
        aadhaarCardPhoto: aadhaarPhotoUrl,
        personPhoto: personPhotoUrl,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        dob: widget.guest.dob,
        isBlacklisted: widget.guest.isBlacklisted,
        blacklistReason: widget.guest.blacklistReason,
        blacklistedBy: widget.guest.blacklistedBy,
        blacklistedAt: widget.guest.blacklistedAt,
        createdByOwnerId: widget.guest.createdByOwnerId,
        createdAt: widget.guest.createdAt,
      );

      await db.updateGuest(updatedGuest);

      if (mounted) {
        ref.read(staysProvider.notifier).loadStays();
        ref.invalidate(guestStayHistoryProvider(widget.guest.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guest details updated successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update guest details: $e'), backgroundColor: AppColors.alertRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _confirmDeleteGuest(BuildContext context) {
    if (widget.guest.isBlacklisted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.block_rounded, color: AppColors.alertRed, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text('Cannot Delete Blacklisted Guest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: Text(
            'Guest "${widget.guest.name}" is currently blacklisted.\n\n'
            'A blacklisted guest profile cannot be deleted. If you need to delete this profile, you must first remove their blacklist status (un-blacklist) and then proceed with deletion.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPill,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: AppColors.alertRed, size: 28),
            SizedBox(width: 10),
            Text('Delete Guest Profile?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${widget.guest.name}"?\n\nThis will permanently delete this guest\'s identity record and remove all associated stay and payment ledger history. This action cannot be undone.',
          style: const TextStyle(fontSize: 14),
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
                await ref.read(staysProvider.notifier).deleteGuest(widget.guest.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Guest profile "${widget.guest.name}" deleted successfully.')),
                  );
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete guest profile: $e'), backgroundColor: AppColors.alertRed),
                  );
                }
              }
            },
            child: const Text('DELETE GUEST', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReplicaHeaderScaffold(
      title: 'Edit Guest Profile',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Identity Card Header
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.glassCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPill.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.badge_rounded, color: AppColors.primaryPill, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.guest.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Aadhaar: ${widget.guest.aadhaarNo} (Verified ID)',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Photo Pickers Card
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
                        'PROFILE & DOCUMENT PHOTOS',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppColors.primaryPill,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          // Face Photo Card
                          Expanded(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _pickImage(true),
                                  child: Container(
                                    height: 120,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.primaryPill.withOpacity(0.5)),
                                      color: Colors.white,
                                    ),
                                    child: _personPhotoFile != null
                                        ? Image.file(_personPhotoFile!, fit: BoxFit.cover, width: double.infinity)
                                        : (widget.guest.personPhoto.isNotEmpty)
                                            ? AppImageHelper.buildImage(widget.guest.personPhoto, fit: BoxFit.cover, width: double.infinity)
                                            : const Center(
                                                child: Icon(Icons.add_a_photo_outlined, size: 28, color: AppColors.primaryPill),
                                              ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text('Face Photo (Tap to change)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Aadhaar Photo Card
                          Expanded(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _pickImage(false),
                                  child: Container(
                                    height: 120,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.primaryPill.withOpacity(0.5)),
                                      color: Colors.white,
                                    ),
                                    child: _aadhaarPhotoFile != null
                                        ? Image.file(_aadhaarPhotoFile!, fit: BoxFit.cover, width: double.infinity)
                                        : (widget.guest.aadhaarCardPhoto != null && widget.guest.aadhaarCardPhoto!.isNotEmpty)
                                            ? AppImageHelper.buildImage(widget.guest.aadhaarCardPhoto!, fit: BoxFit.cover, width: double.infinity)
                                            : const Center(
                                                child: Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppColors.primaryPill),
                                              ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text('Aadhaar Card (Tap)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Main Details Form Card
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
                        'PERSONAL & CONTACT DETAILS',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppColors.primaryPill,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_rounded)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mobileController,
                        decoration: const InputDecoration(labelText: 'Mobile Number *', prefixIcon: Icon(Icons.phone_rounded)),
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final cleaned = v.trim().replaceAll(RegExp(r'\D'), '');
                          if (cleaned.length != 10) return 'Must be a 10-digit mobile number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fatherNameController,
                        decoration: const InputDecoration(labelText: 'Father\'s Name *', prefixIcon: Icon(Icons.family_restroom_rounded)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _policeController,
                        decoration: const InputDecoration(labelText: 'Police Station Circle *', prefixIcon: Icon(Icons.local_police_rounded)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address *', prefixIcon: Icon(Icons.location_on_rounded)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City *', prefixIcon: Icon(Icons.location_city_rounded)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: indianStatesAndUTs.contains(_stateController.text) ? _stateController.text : null,
                        decoration: const InputDecoration(labelText: 'State *', prefixIcon: Icon(Icons.map_rounded)),
                        items: indianStatesAndUTs
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _stateController.text = val);
                        },
                        validator: (v) => _stateController.text.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pincodeController,
                        decoration: const InputDecoration(labelText: 'Pincode *', prefixIcon: Icon(Icons.pin_drop_rounded)),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save Action Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPill,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _isSaving ? null : _saveChanges,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'SAVING...' : 'SAVE GUEST PROFILE',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.guest.isBlacklisted ? const Color(0xFF94A3B8) : AppColors.alertRed,
                      side: BorderSide(
                        color: widget.guest.isBlacklisted ? const Color(0xFFCBD5E1) : AppColors.alertRed,
                        width: 1.5,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _isSaving ? null : () => _confirmDeleteGuest(context),
                    icon: Icon(
                      widget.guest.isBlacklisted ? Icons.lock_outline_rounded : Icons.delete_outline_rounded,
                      size: 20,
                    ),
                    label: Text(
                      widget.guest.isBlacklisted ? 'DELETE LOCKED (GUEST BLACKLISTED)' : 'DELETE GUEST PROFILE',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }
  }
