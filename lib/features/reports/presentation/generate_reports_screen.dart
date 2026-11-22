import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/models.dart';
import '../../../core/models/subscription_plan.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/replica_header_scaffold.dart';
import 'pdf_report_viewer_screen.dart';

class GenerateReportsScreen extends ConsumerStatefulWidget {
  const GenerateReportsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GenerateReportsScreen> createState() => _GenerateReportsScreenState();
}

class _GenerateReportsScreenState extends ConsumerState<GenerateReportsScreen> {
  String _selectedPropertyId = 'ALL';
  String _selectedStatus = 'all'; // 'all', 'active', 'checked_out'
  bool _filterBlacklistedOnly = false;
  DateTimeRange? _checkInDateRange;
  DateTimeRange? _checkOutDateRange;
  bool _isGenerating = false;

  List<Stay> _getFilteredStays(List<Stay> rawStays) {
    return rawStays.map((s) {
      final person = dbService.getCachedPersonById(s.personId) ?? s.person;
      final room = dbService.getCachedRoomById(s.roomId, s.propertyId) ?? s.room;
      return Stay(
        id: s.id,
        personId: s.personId,
        roomId: s.roomId,
        propertyId: s.propertyId,
        ownerId: s.ownerId,
        checkInDate: s.checkInDate,
        checkOutDate: s.checkOutDate,
        rentalTypeUsed: s.rentalTypeUsed,
        agreedRate: s.agreedRate,
        status: s.status,
        createdAt: s.createdAt,
        person: person,
        room: room,
      );
    }).where((s) {
      // 1. Property Filter
      if (_selectedPropertyId != 'ALL' && s.propertyId != _selectedPropertyId) {
        return false;
      }

      // 2. Status Filter
      if (_selectedStatus == 'active' && s.status != 'active') {
        return false;
      }
      if (_selectedStatus == 'checked_out' && s.status == 'active') {
        return false;
      }

      // 3. Blacklist Filter
      if (_filterBlacklistedOnly && s.person?.isBlacklisted != true) {
        return false;
      }

      // 4. Check-in Date Filter (boundary-safe in local time)
      if (_checkInDateRange != null) {
        final start = DateTime(
          _checkInDateRange!.start.year,
          _checkInDateRange!.start.month,
          _checkInDateRange!.start.day,
        );
        final end = DateTime(
          _checkInDateRange!.end.year,
          _checkInDateRange!.end.month,
          _checkInDateRange!.end.day,
          23,
          59,
          59,
          999,
        );
        final checkIn = s.checkInDate.toLocal();
        if (checkIn.isBefore(start) || checkIn.isAfter(end)) {
          return false;
        }
      }

      // 5. Check-out Date Filter (boundary-safe in local time)
      if (_checkOutDateRange != null) {
        if (s.checkOutDate == null) return false;
        final start = DateTime(
          _checkOutDateRange!.start.year,
          _checkOutDateRange!.start.month,
          _checkOutDateRange!.start.day,
        );
        final end = DateTime(
          _checkOutDateRange!.end.year,
          _checkOutDateRange!.end.month,
          _checkOutDateRange!.end.day,
          23,
          59,
          59,
          999,
        );
        final checkOut = s.checkOutDate!.toLocal();
        if (checkOut.isBefore(start) || checkOut.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _generateReport(List<Stay> filteredStays, List<Property> properties) async {
    if (filteredStays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No guests match the selected filters. Please adjust the filters and try again.'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      String propertyName;
      String propertyAddress;

      if (_selectedPropertyId == 'ALL') {
        propertyName = properties.length == 1
            ? properties.first.name
            : 'All Properties (${properties.length})';
        propertyAddress = properties.isNotEmpty
            ? '${properties.first.city}, ${properties.first.state}'
            : 'Consolidated Property Portfolio';
      } else {
        final selectedProp = properties.firstWhere(
          (p) => p.id == _selectedPropertyId,
          orElse: () => properties.first,
        );
        propertyName = selectedProp.name;
        propertyAddress =
            '${selectedProp.address}, ${selectedProp.city}, ${selectedProp.state} - ${selectedProp.pincode}';
      }

      final owner = ref.read(authProvider).value;
      final isFree = !SubscriptionPlanConfig.isPaidPlan(owner?.subscriptionPlan) &&
          !SubscriptionPlanConfig.isTrialActive(owner);

      final pdfBytes = await PdfService.instance.generatePoliceReport(
        propertyName: propertyName,
        propertyAddress: propertyAddress,
        businessName: (owner?.fullName.trim().isNotEmpty ?? false) ? owner!.fullName.trim() : owner?.businessName,
        businessAddress: owner?.businessAddress,
        stays: filteredStays,
        dateRange: _checkInDateRange ?? _checkOutDateRange,
        isFreeTier: isFree,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfReportViewerScreen(
              pdfBytes: pdfBytes,
              title: '$propertyName Report',
              fileName: 'official_guest_registration_${DateTime.now().millisecondsSinceEpoch}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertiesProvider).value ?? [];
    final rawStays = ref.watch(staysProvider).value ?? [];
    final filteredStays = _getFilteredStays(rawStays);

    return ReplicaHeaderScaffold(
      title: 'Official Guest Registration Reports',
      showBackButton: true,
      body: Container(
        decoration: AppColors.backgroundGradient,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(22),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPill.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.primaryPill,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reports Control Desk',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Configure filters to generate official police-compliant records.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Target Property Dropdown
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedPropertyId,
                      items: [
                        const DropdownMenuItem(
                          value: 'ALL',
                          child: Text('All Properties (Consolidated Ledger)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...properties.map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPropertyId = val);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Target Property',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Stay Status Dropdown
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Guests (Active & Checked-Out)'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active Guests Only (Currently Checked-In)'),
                        ),
                        DropdownMenuItem(
                          value: 'checked_out',
                          child: Text('Checked-Out Guests Only (Past Stays)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Guest Residency Status',
                        prefixIcon: Icon(Icons.people_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Check-in Date range picker
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: _checkInDateRange,
                          helpText: 'Select Check-in Date Range',
                        );
                        if (picked != null) {
                          setState(() => _checkInDateRange = picked);
                        }
                      },
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _checkInDateRange == null
                                  ? 'Filter by Check-in Date Range'
                                  : 'Check-in: ${_formatDate(_checkInDateRange!.start)} - ${_formatDate(_checkInDateRange!.end)}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: _checkInDateRange != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (_checkInDateRange != null)
                            GestureDetector(
                              onTap: () => setState(() => _checkInDateRange = null),
                              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.alertRed),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Check-out Date range picker
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: _checkOutDateRange,
                          helpText: 'Select Check-out Date Range',
                        );
                        if (picked != null) {
                          setState(() => _checkOutDateRange = picked);
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _checkOutDateRange == null
                                  ? 'Filter by Check-out Date Range'
                                  : 'Check-out: ${_formatDate(_checkOutDateRange!.start)} - ${_formatDate(_checkOutDateRange!.end)}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: _checkOutDateRange != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (_checkOutDateRange != null)
                            GestureDetector(
                              onTap: () => setState(() => _checkOutDateRange = null),
                              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.alertRed),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Blacklist Toggle Card
                    Container(
                      decoration: BoxDecoration(
                        color: _filterBlacklistedOnly
                            ? AppColors.alertRed.withOpacity(0.08)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _filterBlacklistedOnly
                              ? AppColors.alertRed.withOpacity(0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        title: const Text(
                          'Blacklisted / Flagged Guests Only',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Restrict report strictly to guests flagged with platform warnings',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        activeColor: AppColors.alertRed,
                        value: _filterBlacklistedOnly,
                        onChanged: (val) {
                          setState(() => _filterBlacklistedOnly = val ?? false);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Live Filter Matching Count Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: filteredStays.isNotEmpty
                            ? AppColors.verifiedGreen.withOpacity(0.1)
                            : AppColors.alertRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: filteredStays.isNotEmpty
                              ? AppColors.verifiedGreen.withOpacity(0.3)
                              : AppColors.alertRed.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            filteredStays.isNotEmpty
                                ? Icons.check_circle_outline_rounded
                                : Icons.info_outline_rounded,
                            color: filteredStays.isNotEmpty
                                ? AppColors.verifiedGreen
                                : AppColors.alertRed,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              filteredStays.isNotEmpty
                                  ? '${filteredStays.length} guest${filteredStays.length == 1 ? '' : 's'} match this report configuration'
                                  : 'No guests match the selected filter combination',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: filteredStays.isNotEmpty
                                    ? AppColors.verifiedGreen
                                    : AppColors.alertRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Generate Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPill,
                          shape: const StadiumBorder(),
                          elevation: 2,
                        ),
                        onPressed: _isGenerating
                            ? null
                            : () => _generateReport(filteredStays, properties),
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(
                          _isGenerating
                              ? 'GENERATING SECURE REPORT...'
                              : 'GENERATE & PREVIEW REPORT',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
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

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
