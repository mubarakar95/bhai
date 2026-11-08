import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/subscription_plan.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/subscription_upgrade_dialog.dart';
import 'add_edit_property_screen.dart';
import 'property_detail_screen.dart';
import '../../../core/widgets/replica_header_scaffold.dart';

class PropertiesScreen extends ConsumerStatefulWidget {
  const PropertiesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends ConsumerState<PropertiesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesState = ref.watch(propertiesProvider);

    return ReplicaHeaderScaffold(
      title: 'Property Directory',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryPill,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add Property', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          final properties = propertiesState.value ?? [];
          final owner = ref.read(authProvider).value;
          final check = SubscriptionPlanConfig.checkCanAddProperty(
            owner: owner,
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEditPropertyScreen()),
          );
        },
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Property Search Bar
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.glassCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search properties by name, city, address...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryPill, size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                ),
              ),

              // Properties Directory
              propertiesState.when(
                data: (properties) {
                  final allStays = ref.watch(staysProvider).value ?? [];

                  // Calculate aggregate statistics across all properties
                  int totalRoomsAll = 0;
                  int totalAccommodatedAll = 0;
                  for (var p in properties) {
                    final rList = ref.watch(roomsProvider(p.id)).value ?? dbService.getCachedRooms(p.id);
                    totalRoomsAll += rList.length;
                    final occ = rList.fold<int>(0, (sum, r) => sum + r.currentOccupancy);
                    final pStays = allStays.where((s) => s.propertyId == p.id && s.status == 'active').length;
                    totalAccommodatedAll += math.max(occ, pStays);
                  }

                  final filteredProperties = properties.where((p) {
                    if (_searchQuery.isEmpty) return true;
                    return p.name.toLowerCase().contains(_searchQuery) ||
                        p.address.toLowerCase().contains(_searchQuery) ||
                        p.city.toLowerCase().contains(_searchQuery) ||
                        p.state.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (properties.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.glassCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Center(
                        child: Text(
                          'No properties registered yet.\nTap "Add Property" above to create your first listing.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (filteredProperties.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.glassCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded, size: 36, color: AppColors.textMuted),
                          const SizedBox(height: 10),
                          Text(
                            'No properties found matching "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Text('Clear Search'),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Overall Metric Strip across all properties
                      if (properties.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.glassCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.glassBorder),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 12,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildOverviewItem(
                                label: 'Properties',
                                value: '${properties.length}',
                                icon: Icons.business_rounded,
                                color: AppColors.primaryPill,
                              ),
                              Container(height: 24, width: 1, color: AppColors.glassBorder),
                              _buildOverviewItem(
                                label: 'Total Rooms',
                                value: '$totalRoomsAll',
                                icon: Icons.meeting_room_outlined,
                                color: AppColors.primaryPill,
                              ),
                              Container(height: 24, width: 1, color: AppColors.glassBorder),
                              _buildOverviewItem(
                                label: 'Accommodated',
                                value: '$totalAccommodatedAll Guests',
                                icon: Icons.people_alt_outlined,
                                color: AppColors.verifiedGreen,
                              ),
                            ],
                          ),
                        ),

                      // Filtered Property Cards
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredProperties.length,
                        itemBuilder: (context, idx) {
                          final prop = filteredProperties[idx];
                          final rooms = ref.watch(roomsProvider(prop.id)).value ?? dbService.getCachedRooms(prop.id);
                          final roomsCount = rooms.length;
                          final roomOccupancy = rooms.fold<int>(0, (sum, r) => sum + r.currentOccupancy);
                          final totalCapacity = rooms.fold<int>(0, (sum, r) => sum + r.capacity);
                          final activeStaysCount = allStays.where((s) => s.propertyId == prop.id && s.status == 'active').length;
                          final totalAccommodated = math.max(roomOccupancy, activeStaysCount);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppColors.glassCard,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.glassBorder),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PropertyDetailScreen(property: prop),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryPill.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.business_rounded, color: AppColors.primaryPill, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              prop.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${prop.address}, ${prop.city}, ${prop.state}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Mob: ${prop.contactNo}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                // Rooms Count Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryPill.withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AppColors.primaryPill.withOpacity(0.2)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.meeting_room_outlined, size: 13, color: AppColors.primaryPill),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$roomsCount ${roomsCount == 1 ? 'Room' : 'Rooms'}',
                                                        style: const TextStyle(
                                                          color: AppColors.primaryPill,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Accommodated Count Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                  decoration: BoxDecoration(
                                                    color: totalAccommodated > 0
                                                        ? AppColors.verifiedGreen.withOpacity(0.08)
                                                        : Colors.black.withOpacity(0.04),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: totalAccommodated > 0
                                                          ? AppColors.verifiedGreen.withOpacity(0.25)
                                                          : Colors.grey.withOpacity(0.2),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.people_alt_outlined,
                                                        size: 13,
                                                        color: totalAccommodated > 0
                                                            ? AppColors.verifiedGreen
                                                            : AppColors.textSecondary,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        totalCapacity > 0
                                                            ? '$totalAccommodated Accommodated ($totalCapacity Beds)'
                                                            : '$totalAccommodated Accommodated',
                                                        style: TextStyle(
                                                          color: totalAccommodated > 0
                                                              ? AppColors.verifiedGreen
                                                              : AppColors.textSecondary,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 22),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.alertRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.alertRed.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.alertRed, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Unable to load properties: $e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.alertRed, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPill,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          ref.read(propertiesProvider.notifier).loadProperties();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
