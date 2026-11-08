import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../providers/app_providers.dart';

class ReplicaHeaderScaffold extends ConsumerStatefulWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final String? subtitle;
  final bool resizeToAvoidBottomInset;

  const ReplicaHeaderScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
    this.subtitle,
    this.resizeToAvoidBottomInset = true,
  }) : super(key: key);

  @override
  ConsumerState<ReplicaHeaderScaffold> createState() => _ReplicaHeaderScaffoldState();
}

class _ReplicaHeaderScaffoldState extends ConsumerState<ReplicaHeaderScaffold> {
  bool _isHeaderVisible = true;

  Widget _buildAvatarWidget(Owner? owner, double size) {
    if (owner != null && owner.avatarUrl != null && owner.avatarUrl!.isNotEmpty) {
      final avatar = owner.avatarUrl!;
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        return Image.network(
          avatar,
          key: ValueKey(avatar),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(owner, size),
        );
      } else {
        final file = File(avatar);
        if (file.existsSync()) {
          return Image.file(
            file,
            key: ValueKey(avatar),
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(owner, size),
          );
        }
      }
    }
    return _buildInitialsAvatar(owner, size);
  }

  Widget _buildInitialsAvatar(Owner? owner, double size) {
    final name = owner?.fullName.trim() ?? 'Bhai';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';
    return Container(
      width: size,
      height: size,
      color: Colors.white.withOpacity(0.25),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showNotificationModal(BuildContext context, List<Stay> activeStays) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: AppColors.primaryPill),
                const SizedBox(width: 8),
                Text(
                  'Pending Alerts & Active Stays',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${activeStays.length} Active',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPill),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activeStays.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No active guest stays or pending payment alerts.', textAlign: TextAlign.center),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: activeStays.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final stay = activeStays[index];
                    final guestName = stay.person?.name ?? 'Guest #${stay.personId.substring(0, 4)}';
                    final roomNo = stay.room?.roomNumber ?? 'Room';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryPill,
                        child: Icon(Icons.person_outline, color: Colors.white, size: 20),
                      ),
                      title: Text(guestName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Room: $roomNo • Rate: ₹${stay.agreedRate.toStringAsFixed(0)}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.verifiedBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('ACTIVE', style: TextStyle(color: AppColors.verifiedGreen, fontSize: 10, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final ownerState = ref.watch(authProvider);
    final staysState = ref.watch(staysProvider);

    final owner = ownerState.asData?.value;
    final activeStays = (staysState.asData?.value ?? []).where((s) => s.status == 'active').toList();
    final alertCount = activeStays.length;
    const displayTitle = 'Bhai App';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Scaffold(
            resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
            backgroundColor: AppColors.primary,
            floatingActionButton: widget.floatingActionButton,
            floatingActionButtonLocation: widget.floatingActionButtonLocation,
            bottomNavigationBar: widget.bottomNavigationBar,
            body: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final delta = notification.scrollDelta;
                  final metrics = notification.metrics;
                  if (metrics.axis == Axis.vertical) {
                    if (metrics.pixels <= 10) {
                      if (!_isHeaderVisible) {
                        setState(() => _isHeaderVisible = true);
                      }
                    } else if (delta != null && delta > 4) {
                      if (_isHeaderVisible) {
                        setState(() => _isHeaderVisible = false);
                      }
                    } else if (delta != null && delta < -6) {
                      if (!_isHeaderVisible) {
                        setState(() => _isHeaderVisible = true);
                      }
                    }
                  }
                }
                return false;
              },
              child: Column(
                children: [
                  // Top Replica Header Bar (Adapts & Collapses on Scroll)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                    height: _isHeaderVisible ? 62 : 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isHeaderVisible ? 1.0 : 0.0,
                      child: ClipRect(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // Brand Logo & Real Owner Business Name
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Image.asset(
                                            'assets/logo.png',
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(
                                              Icons.spa_rounded,
                                              color: AppColors.primary,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 180),
                                      child: Text(
                                        displayTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Notification Bell with Real Badge Count
                                GestureDetector(
                                  onTap: () => _showNotificationModal(context, activeStays),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.22),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.notifications_outlined,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      if (alertCount > 0)
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: AppColors.primary, width: 1.5),
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 16,
                                              minHeight: 16,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$alertCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Real User Profile Avatar
                                GestureDetector(
                                  onTap: () {
                                    // Pop any pushed child screens back to the root home shell
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                    // Switch bottom navigation tab to Settings (index 3)
                                    ref.read(homeNavIndexProvider.notifier).state = 3;
                                  },
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _buildAvatarWidget(owner, 38),
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

                  // Main Rounded White Body Sheet (Adapts when header collapses)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.fastOutSlowIn,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: _isHeaderVisible
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(28),
                                topRight: Radius.circular(28),
                              )
                            : BorderRadius.zero,
                      ),
                      child: ClipRRect(
                        borderRadius: _isHeaderVisible
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(28),
                                topRight: Radius.circular(28),
                              )
                            : BorderRadius.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header area inside the sheet
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: widget.showBackButton
                                  ? Row(
                                      children: [
                                        GestureDetector(
                                          onTap: widget.onBackPressed ?? () => Navigator.pop(context),
                                          behavior: HitTestBehavior.opaque,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            child: const Icon(
                                              Icons.arrow_back_ios_new_rounded,
                                              size: 18,
                                              color: AppColors.textMain,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.title,
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                      color: AppColors.textMain,
                                                    ),
                                              ),
                                              if (widget.subtitle != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  widget.subtitle!,
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (widget.actions != null) ...widget.actions!,
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.title,
                                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 24,
                                                    color: AppColors.textMain,
                                                  ),
                                            ),
                                            if (widget.subtitle != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                widget.subtitle!,
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (widget.actions != null) Row(children: widget.actions!),
                                      ],
                                    ),
                            ),
                            Expanded(child: widget.body),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
