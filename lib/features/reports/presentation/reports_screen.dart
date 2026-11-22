import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/models.dart';
import '../../../core/models/subscription_plan.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _selectedPropertyId;
  bool _filterBlacklistedOnly = false;
  DateTimeRange? _checkInDateRange;
  DateTimeRange? _checkOutDateRange;

  Uint8List? _pdfBytes;
  bool _isGenerating = false;

  Future<void> _generateReport(List<Stay> stays, List<Property> properties) async {
    if (stays.isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      final selectedProp = properties.firstWhere(
        (p) => p.id == _selectedPropertyId,
        orElse: () => properties.first,
      );

      // Filter stays based on chosen criteria
      var filteredStays = stays.where((s) => s.propertyId == selectedProp.id).toList();

      if (_filterBlacklistedOnly) {
        filteredStays = filteredStays.where((s) => s.person?.isBlacklisted == true).toList();
      }

      if (_checkInDateRange != null) {
        filteredStays = filteredStays.where((s) {
          final checkIn = s.checkInDate;
          return checkIn.isAfter(_checkInDateRange!.start.subtract(const Duration(seconds: 1))) &&
              checkIn.isBefore(_checkInDateRange!.end.add(const Duration(days: 1)));
        }).toList();
      }

      if (_checkOutDateRange != null) {
        filteredStays = filteredStays.where((s) {
          if (s.checkOutDate == null) return false;
          final checkOut = s.checkOutDate!;
          return checkOut.isAfter(_checkOutDateRange!.start.subtract(const Duration(seconds: 1))) &&
              checkOut.isBefore(_checkOutDateRange!.end.add(const Duration(days: 1)));
        }).toList();
      }

      final owner = ref.read(authProvider).value;
      final isFree = !SubscriptionPlanConfig.isPaidPlan(owner?.subscriptionPlan) &&
          !SubscriptionPlanConfig.isTrialActive(owner);

      final pdfBytes = await PdfService.instance.generatePoliceReport(
        propertyName: selectedProp.name,
        propertyAddress: '${selectedProp.address}, ${selectedProp.city}, ${selectedProp.state} - ${selectedProp.pincode}',
        businessName: (owner?.fullName.trim().isNotEmpty ?? false) ? owner!.fullName.trim() : owner?.businessName,
        businessAddress: owner?.businessAddress,
        stays: filteredStays,
        dateRange: _checkInDateRange ?? _checkOutDateRange,
        isFreeTier: isFree,
      );

      setState(() {
        _pdfBytes = pdfBytes;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e'), backgroundColor: AppColors.alertRed),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertiesProvider).value ?? [];
    final stays = ref.watch(staysProvider).value ?? [];

    // Preselect first property if none selected
    if (_selectedPropertyId == null && properties.isNotEmpty) {
      _selectedPropertyId = properties.first.id;
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    Widget controlsPanel = Container(
      margin: isMobile ? const EdgeInsets.all(16) : const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            'Reports Control Desk',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          if (properties.isEmpty)
            const Text('No properties available to report.')
          else ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedPropertyId,
              items: properties
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedPropertyId = val;
                  _pdfBytes = null;
                });
              },
              decoration: const InputDecoration(labelText: 'Target Property', prefixIcon: Icon(Icons.business_rounded)),
            ),
            const SizedBox(height: 12),
          ],

          // Check-in Date range picker
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 305)),
                initialDateRange: _checkInDateRange,
                helpText: 'Select Check-in Date Range',
              );
              if (picked != null) {
                setState(() {
                  _checkInDateRange = picked;
                  _pdfBytes = null;
                });
              }
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: Text(
              _checkInDateRange == null
                  ? 'CHECK-IN DATE RANGE'
                  : 'Check-in: ${_formatDate(_checkInDateRange!.start)} - ${_formatDate(_checkInDateRange!.end)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_checkInDateRange != null) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _checkInDateRange = null;
                    _pdfBytes = null;
                  });
                },
                child: const Text('Clear Check-in Range', style: TextStyle(color: AppColors.alertRed, fontSize: 11)),
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Check-out Date range picker
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 305)),
                initialDateRange: _checkOutDateRange,
                helpText: 'Select Check-out Date Range',
              );
              if (picked != null) {
                setState(() {
                  _checkOutDateRange = picked;
                  _pdfBytes = null;
                });
              }
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              _checkOutDateRange == null
                  ? 'CHECK-OUT DATE RANGE'
                  : 'Check-out: ${_formatDate(_checkOutDateRange!.start)} - ${_formatDate(_checkOutDateRange!.end)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_checkOutDateRange != null) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _checkOutDateRange = null;
                    _pdfBytes = null;
                  });
                },
                child: const Text('Clear Check-out Range', style: TextStyle(color: AppColors.alertRed, fontSize: 11)),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Blacklist Toggle
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Blacklisted Guests Only', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            activeColor: AppColors.alertRed,
            value: _filterBlacklistedOnly,
            onChanged: (val) {
              setState(() {
                _filterBlacklistedOnly = val ?? false;
                _pdfBytes = null;
              });
            },
          ),

          if (!isMobile) const Spacer() else const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPill,
                shape: const StadiumBorder(),
              ),
              onPressed: stays.isEmpty || _isGenerating
                  ? null
                  : () => _generateReport(stays, properties),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: const Text(
                'GENERATE & DOWNLOAD REPORT',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    Widget previewPanel = Container(
      color: Colors.transparent,
      child: _pdfBytes != null
          ? PdfPreview(
              build: (format) => _pdfBytes!,
              useActions: true,
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              pdfFileName: 'official_guest_registration_report.pdf',
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.description_outlined, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'Report Preview Inactive',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    const Text('Adjust filters and tap Generate to preview and download PDF.', style: TextStyle(fontSize: 13), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Official Guest Registration Reports'),
      ),
      body: isMobile
          ? SingleChildScrollView(
              child: Column(
                children: [
                  controlsPanel,
                  SizedBox(
                    height: 550,
                    child: previewPanel,
                  ),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: controlsPanel,
                ),
                Expanded(
                  flex: 3,
                  child: previewPanel,
                ),
              ],
            ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
