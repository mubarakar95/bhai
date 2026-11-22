import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/colors.dart';
import '../core/providers/app_providers.dart';
import '../core/services/app_update_service.dart';
import '../core/services/supabase_service.dart';
import 'dashboard/presentation/dashboard_screen.dart';
import 'guests/presentation/guests_screen.dart';
import 'properties/presentation/properties_screen.dart';
import 'settings/presentation/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final List<Widget> _screens = const [
    DashboardScreen(),
    GuestsScreen(),
    PropertiesScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Defer non-critical cloud version check slightly so app startup and touch responses are silky smooth
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _checkForForceUpdate();
      });
      _runDailyAccounts();
    });
  }

  /// First open of the day: recalculate everybody's balances from fresh data.
  Future<void> _runDailyAccounts() async {
    final ran = await SupabaseService.instance.runDailyCalculationIfNeeded();
    if (!ran || !mounted) return;
    await ref.read(staysProvider.notifier).loadStays();
    ref.invalidate(billingSummaryProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Today's accounts have been calculated."),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _checkForForceUpdate() async {
    final updateInfo = await AppUpdateService().fetchUpdateInfo();
    if (updateInfo != null && updateInfo.requiresForceUpdate && mounted) {
      AppUpdateService.showForceUpdateModal(context, updateInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(homeNavIndexProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Container(
        decoration: AppColors.backgroundGradient,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _screens[currentIndex],
          bottomNavigationBar: SafeArea(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.glassBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildNavItem(0, Icons.grid_view_rounded, 'Dashboard', currentIndex),
                  _buildNavItem(1, Icons.people_alt_rounded, 'Guests', currentIndex),
                  _buildNavItem(2, Icons.business_rounded, 'Properties', currentIndex),
                  _buildNavItem(3, Icons.tune_rounded, 'Settings', currentIndex),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, int currentIndex) {
    final bool isSelected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(homeNavIndexProvider.notifier).state = index,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryPill.withOpacity(0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected ? AppColors.primaryPill : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppColors.primaryPill : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12.5,
                  letterSpacing: isSelected ? 0.2 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
