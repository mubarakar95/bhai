import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/models/models.dart';
import '../../guests/presentation/guests_screen.dart';
import '../../guests/presentation/add_guest_flow.dart';
import '../../reports/presentation/generate_reports_screen.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/widgets/replica_header_scaffold.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final propertiesState = ref.watch(propertiesProvider);
    final staysState = ref.watch(staysProvider);

    return ReplicaHeaderScaffold(
      title: 'Dashboard',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(propertiesProvider.notifier).loadProperties();
          await ref.read(staysProvider.notifier).loadStays();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Consolidated Glass Stat Cards & Circular Occupancy Ring
                propertiesState.when(
                  data: (properties) => staysState.when(
                    data: (stays) {
                      final totalProperties = properties.length;
                      final activeStays = stays.where((s) => s.status == 'active').toList();
                      final totalGuests = activeStays.length;

                      double totalToReceive = 0;
                      double totalToGive = 0;
                      final List<Map<String, dynamic>> toReceiveItems = [];
                      final List<Map<String, dynamic>> toGiveItems = [];

                      for (var stay in activeStays) {
                        final billing = dbService.getLocalBillingSummary(stay.id);
                        final pending = billing.pendingAmount;
                        if (pending > 0) {
                          totalToReceive += pending;
                          toReceiveItems.add({'stay': stay, 'amount': pending});
                        } else if (pending < 0) {
                          totalToGive += pending.abs();
                          toGiveItems.add({'stay': stay, 'amount': pending.abs()});
                        }
                      }

                      // Calculate occupancy percentage from local cached rooms instantly
                      int totalCapacity = 0;
                      int currentOccupancy = 0;
                      for (var p in properties) {
                        final rooms = dbService.getCachedRooms(p.id);
                        for (var r in rooms) {
                          totalCapacity += r.capacity;
                          currentOccupancy += r.currentOccupancy;
                        }
                      }

                      final occupancyRatio = totalCapacity > 0
                          ? (currentOccupancy / totalCapacity).clamp(0.0, 1.0)
                          : 0.0;

                      return Column(
                        children: [
                          // Occupancy Ring Header Card
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
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox.expand(
                                        child: CircularProgressIndicator(
                                          value: occupancyRatio,
                                          strokeWidth: 7,
                                          backgroundColor: AppColors.brandBlue.withOpacity(0.15),
                                          color: AppColors.brandBlue,
                                          strokeCap: StrokeCap.round,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '${(occupancyRatio * 100).toInt()}%',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textMain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Overall Occupancy',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$currentOccupancy of $totalCapacity beds occupied',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 8),
                                      StatusBadge.verified(label: 'VERIFIED SECURE'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Stat Cards Grid (Properties & Guests)
                          Row(
                            children: [
                              Expanded(
                                child: _buildGlassStatCard(
                                  context,
                                  'PROPERTIES',
                                  totalProperties.toString(),
                                  Icons.business_rounded,
                                  AppColors.primaryPill,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildGlassStatCard(
                                  context,
                                  'GUESTS',
                                  totalGuests.toString(),
                                  Icons.people_alt_rounded,
                                  AppColors.verifiedGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Split Pending Balance Cards: To Receive & To Give
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showBalanceGuestSheet(
                                    context,
                                    'Amount to Receive (Guest Dues)',
                                    toReceiveItems,
                                    isReceive: true,
                                  ),
                                  child: _buildGlassStatCard(
                                    context,
                                    'TO RECEIVE',
                                    '₹${totalToReceive.toStringAsFixed(2)}',
                                    Icons.south_west_rounded,
                                    AppColors.verifiedGreen,
                                    subtitle: '${toReceiveItems.length} guests owe',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showBalanceGuestSheet(
                                    context,
                                    'Amount to Give (Refunds Due)',
                                    toGiveItems,
                                    isReceive: false,
                                  ),
                                  child: _buildGlassStatCard(
                                    context,
                                    'TO GIVE',
                                    '₹${totalToGive.toStringAsFixed(2)}',
                                    Icons.north_east_rounded,
                                    AppColors.alertRed,
                                    subtitle: '${toGiveItems.length} guests due',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Redesigned Square Card Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const AddGuestFlow()),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    constraints: const BoxConstraints(minHeight: 115),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPill.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: AppColors.primaryPill.withOpacity(0.4), width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0C000000),
                                          blurRadius: 16,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(9),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryPill,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Allocate Guest',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Check-in new guest',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const GenerateReportsScreen()),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    constraints: const BoxConstraints(minHeight: 115),
                                    decoration: BoxDecoration(
                                      color: AppColors.glassCard,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: AppColors.glassBorder, width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0C000000),
                                          blurRadius: 16,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(9),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryPill.withOpacity(0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryPill, size: 20),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Generate Report',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Official Guest Ledger',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Monthly Activity Card at the bottom most
                          _buildMonthlyAnalyticsWidget(context, stays),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Error loading stats: $e'),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error loading stats: $e'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color iconColor, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyAnalyticsWidget(BuildContext context, List<Stay> stays) {
    final now = DateTime.now();
    int checkInsThisMonth = 0;
    int checkOutsThisMonth = 0;

    for (var stay in stays) {
      if (stay.checkInDate.year == now.year && stay.checkInDate.month == now.month) {
        checkInsThisMonth++;
      }
      if (stay.checkOutDate != null &&
          stay.checkOutDate!.year == now.year &&
          stay.checkOutDate!.month == now.month) {
        checkOutsThisMonth++;
      }
    }

    final maxVal = (checkInsThisMonth + checkOutsThisMonth) > 0
        ? (checkInsThisMonth + checkOutsThisMonth)
        : 1;

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthName = '${monthNames[now.month - 1]} ${now.year}';

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.brandBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.brandBlue),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Monthly Activity',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                  ),
                ],
              ),
              Text(
                monthName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Check-Ins Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Check-ins', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('$checkInsThisMonth', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.verifiedGreen)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: checkInsThisMonth / maxVal,
                  minHeight: 8,
                  backgroundColor: AppColors.verifiedGreen.withOpacity(0.12),
                  color: AppColors.verifiedGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Check-Outs Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Check-outs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('$checkOutsThisMonth', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryPill)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: checkOutsThisMonth / maxVal,
                  minHeight: 8,
                  backgroundColor: AppColors.primaryPill.withOpacity(0.12),
                  color: AppColors.primaryPill,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _money(double v) {
    final whole = v == v.roundToDouble();
    return '₹${NumberFormat(whole ? '#,##,##0' : '#,##,##0.00', 'en_IN').format(v)}';
  }

  /// Builds a short plain-text list for a cash collector: who to collect from,
  /// where they stay, how to reach them and how much. Nothing else (no ID numbers,
  /// photos or rent history). Opens the share sheet so it can go straight to WhatsApp.
  Future<void> _shareCollectionDetails(List<Map<String, dynamic>> items) async {
    final rows = items.map((item) {
      final Stay stay = item['stay'];
      final double amount = item['amount'];
      final person = stay.person ?? dbService.getCachedPersonById(stay.personId);
      final room = stay.room ?? dbService.getCachedRoomById(stay.roomId, stay.propertyId);
      final property = dbService.getCachedPropertyById(stay.propertyId);
      return (
        name: person?.name ?? 'Guest',
        mobile: person?.mobileNo ?? '',
        place: [
          if (property != null) property.name,
          if (room != null) 'Room ${room.roomNumber}',
        ].join(', '),
        amount: amount,
      );
    }).toList()
      ..sort((a, b) {
        final c = a.place.compareTo(b.place);
        return c != 0 ? c : a.name.compareTo(b.name);
      });

    final total = rows.fold<double>(0, (sum, r) => sum + r.amount);
    final b = StringBuffer()
      ..writeln('*Cash to collect* - ${DateFormat('dd MMM yyyy').format(DateTime.now())}')
      ..writeln('Total: *${_money(total)}* from ${rows.length} guest${rows.length == 1 ? '' : 's'}')
      ..writeln();
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      b.writeln('${i + 1}. *${r.name}*');
      if (r.place.isNotEmpty) b.writeln('   ${r.place}');
      if (r.mobile.isNotEmpty) b.writeln('   Mobile: ${r.mobile}');
      b.writeln('   Collect: *${_money(r.amount)}*');
      if (i != rows.length - 1) b.writeln();
    }

    await SharePlus.instance.share(ShareParams(text: b.toString().trimRight()));
  }

  void _showBalanceGuestSheet(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> items, {
    required bool isReceive,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (isReceive && items.isNotEmpty) ...[
                    // Top-left: share a ready-to-send collection list (e.g. to WhatsApp)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.verifiedGreen,
                        backgroundColor: AppColors.verifiedGreen.withOpacity(0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => _shareCollectionDetails(items),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Icon(
                    isReceive ? Icons.south_west_rounded : Icons.north_east_rounded,
                    color: isReceive ? AppColors.verifiedGreen : AppColors.alertRed,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isReceive ? AppColors.verifiedGreen : AppColors.alertRed).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length} Guests',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isReceive ? AppColors.verifiedGreen : AppColors.alertRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isReceive ? 'No pending dues to receive!' : 'No pending refunds to give!',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final Stay stay = item['stay'];
                        final double amount = item['amount'];
                        final person = stay.person ?? dbService.getCachedPersonById(stay.personId);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.glassBorder),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              backgroundImage: AppImageHelper.getImageProvider(person?.personPhoto),
                              radius: 22,
                              child: person?.personPhoto == null || person!.personPhoto.isEmpty
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                            title: Text(
                              person?.name ?? 'Unknown Guest',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              'Mobile: ${person?.mobileNo ?? 'N/A'}\nRate: ₹${stay.agreedRate}/${stay.rentalTypeUsed.toString().split('.').last}',
                              style: const TextStyle(fontSize: 12, height: 1.3),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isReceive ? AppColors.verifiedGreen : AppColors.alertRed,
                                  ),
                                ),
                                Text(
                                  isReceive ? 'To Receive' : 'To Give',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GuestDetailScreen(stay: stay),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
