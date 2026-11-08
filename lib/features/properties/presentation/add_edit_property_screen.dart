import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/indian_states.dart';
import '../../../core/models/models.dart';
import '../../../core/models/subscription_plan.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/replica_header_scaffold.dart';
import '../../../core/widgets/subscription_upgrade_dialog.dart';

class AddEditPropertyScreen extends ConsumerStatefulWidget {
  final Property? property;

  const AddEditPropertyScreen({Key? key, this.property}) : super(key: key);

  @override
  ConsumerState<AddEditPropertyScreen> createState() => _AddEditPropertyScreenState();
}

class _AddEditPropertyScreenState extends ConsumerState<AddEditPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _pincodeController;
  late TextEditingController _contactController;

  late String _selectedState;
  late String _selectedType;
  bool _isSaving = false;

  bool get isEditing => widget.property != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.property?.name ?? '');
    _addressController = TextEditingController(text: widget.property?.address ?? '');
    _cityController = TextEditingController(text: widget.property?.city ?? '');
    _pincodeController = TextEditingController(text: widget.property?.pincode ?? '');
    _contactController = TextEditingController(text: widget.property?.contactNo ?? '');

    _selectedType = widget.property?.propertyType ?? 'PG';
    
    final initialState = widget.property?.state ?? 'Kerala';
    _selectedState = indianStatesAndUTs.contains(initialState) ? initialState : indianStatesAndUTs.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) return;

    final currentOwner = ref.read(authProvider).value;
    final currentOwnerId = currentOwner?.id ?? ref.read(dbServiceProvider).currentOwnerId ?? '';

    if (!isEditing) {
      final properties = ref.read(propertiesProvider).value ?? [];
      final check = SubscriptionPlanConfig.checkCanAddProperty(
        owner: currentOwner,
        currentPropertyCount: properties.length,
      );
      if (!check.canAdd) {
        SubscriptionUpgradeDialog.show(
          context,
          limitWarningTitle: 'Property Limit Reached (Free Tier: 1 Property)',
          limitWarningMessage: check.reason,
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      if (isEditing) {
        final existingOwnerId = widget.property!.ownerId.isNotEmpty ? widget.property!.ownerId : currentOwnerId;
        final updatedProperty = Property(
          id: widget.property!.id,
          ownerId: existingOwnerId,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          state: _selectedState,
          pincode: _pincodeController.text.trim(),
          propertyType: _selectedType,
          contactNo: _contactController.text.trim(),
          photos: widget.property!.photos,
          createdAt: widget.property!.createdAt,
        );

        await ref.read(propertiesProvider.notifier).updateProperty(updatedProperty);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Property details updated successfully.')),
          );
          Navigator.pop(context);
        }
      } else {
        final newProperty = Property(
          id: '',
          ownerId: currentOwnerId,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          state: _selectedState,
          pincode: _pincodeController.text.trim(),
          propertyType: _selectedType,
          contactNo: _contactController.text.trim(),
          photos: [],
          createdAt: DateTime.now(),
        );

        await ref.read(propertiesProvider.notifier).addProperty(newProperty);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Property registered successfully.')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save property: $e'), backgroundColor: AppColors.alertRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _confirmDeleteProperty() {
    if (widget.property == null) return;
    final prop = widget.property!;
    final stays = ref.read(staysProvider).value ?? [];
    final activeStays = stays.where((s) => s.propertyId == prop.id && s.status == 'active').toList();
    if (activeStays.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.alertRed, size: 28),
              SizedBox(width: 10),
              Text('Cannot Delete Property', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'Cannot delete "${prop.name}" because it currently has ${activeStays.length} active checked-in guest(s).\n\nPlease check out or reassign all guests before deleting this property.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPill,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
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
            Text('Delete Property?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${prop.name}"?\n\nThis will remove all associated rooms and past check-in records under this property. This action cannot be undone.',
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
                await ref.read(propertiesProvider.notifier).deleteProperty(prop.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Property "${prop.name}" deleted successfully.')),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete property: $e'), backgroundColor: AppColors.alertRed),
                  );
                }
              }
            },
            child: const Text('DELETE PROPERTY', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReplicaHeaderScaffold(
      title: isEditing ? 'Edit Property Details' : 'Add New Property',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
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
                        decoration: const BoxDecoration(
                          color: AppColors.primaryPill,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_rounded : Icons.business_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'UPDATE LISTING DETAILS' : 'REGISTER NEW PROPERTY',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEditing
                                  ? 'Modify property name, address, and owner contact details.'
                                  : 'Fill in listing address and contact details to manage rooms.',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Form Container Card
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
                        'PROPERTY SPECIFICATIONS',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppColors.primaryPill,
                            ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Property Name *',
                          prefixIcon: Icon(Icons.apartment_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        items: ['PG', 'hostel', 'guest_house', 'camp']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Property Category *',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Street Address *',
                          prefixIcon: Icon(Icons.location_on_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City *',
                          prefixIcon: Icon(Icons.location_city_rounded),
                        ),
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
                          labelText: 'State *',
                          prefixIcon: Icon(Icons.map_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _pincodeController,
                        decoration: const InputDecoration(
                          labelText: 'Pincode *',
                          prefixIcon: Icon(Icons.pin_drop_rounded),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _contactController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Mobile Number (Optional)',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final cleaned = v.trim().replaceAll(RegExp(r'\D'), '');
                          if (cleaned.length != 10) return 'Must be a 10-digit mobile number';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPill,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _isSaving ? null : _saveProperty,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'SAVING...' : (isEditing ? 'UPDATE PROPERTY DETAILS' : 'SAVE NEW PROPERTY'),
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.alertRed,
                        side: const BorderSide(color: AppColors.alertRed, width: 1.5),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _isSaving ? null : _confirmDeleteProperty,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text(
                        'DELETE PROPERTY',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
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
