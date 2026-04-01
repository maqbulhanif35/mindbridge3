import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/admin_provider.dart';

// ─── Admin Nav Items ──────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final Color? badgeColor;
  final String shortcut;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.badgeColor,
    this.shortcut = '',
  });
}

const _navItems = [
  _NavItem(
    label: 'Dashboard',
    icon: LucideIcons.layoutDashboard,
    activeIcon: LucideIcons.layoutDashboard,
    route: '/admin/dashboard',
    shortcut: '⌘1',
  ),
  _NavItem(
    label: 'Users',
    icon: LucideIcons.users,
    activeIcon: LucideIcons.users,
    route: '/admin/users',
    shortcut: '⌘2',
  ),
  _NavItem(
    label: 'Moderation',
    icon: LucideIcons.shield,
    activeIcon: LucideIcons.shieldCheck,
    route: '/admin/moderation',
    badgeColor: AppColors.warning,
    shortcut: '⌘3',
  ),
  _NavItem(
    label: 'Crisis Monitor',
    icon: LucideIcons.triangleAlert,
    activeIcon: LucideIcons.triangleAlert,
    route: '/admin/crisis',
    badgeColor: AppColors.error,
    shortcut: '⌘4',
  ),
  _NavItem(
    label: 'Analytics',
    icon: LucideIcons.chartBar,
    activeIcon: LucideIcons.chartBar,
    route: '/admin/analytics',
    shortcut: '⌘5',
  ),
  _NavItem(
    label: 'Broadcast',
    icon: LucideIcons.megaphone,
    activeIcon: LucideIcons.megaphone,
    route: '/admin/broadcast',
    shortcut: '⌘6',
  ),
  _NavItem(
    label: 'Settings',
    icon: LucideIcons.settings,
    activeIcon: LucideIcons.settings,
    route: '/admin/settings',
    shortcut: '⌘7',
  ),
];

// Bottom nav items (mobile — 5 items including "More")
const _mobileBottomNav = [
  _NavItem(
    label: 'Dashboard',
    icon: LucideIcons.layoutDashboard,
    activeIcon: LucideIcons.layoutDashboard,
    route: '/admin/dashboard',
  ),
  _NavItem(
    label: 'Users',
    icon: LucideIcons.users,
    activeIcon: LucideIcons.users,
    route: '/admin/users',
  ),
  _NavItem(
    label: 'Moderate',
    icon: LucideIcons.shield,
    activeIcon: LucideIcons.shieldCheck,
    route: '/admin/moderation',
    badgeColor: AppColors.warning,
  ),
  _NavItem(
    label: 'Crisis',
    icon: LucideIcons.triangleAlert,
    activeIcon: LucideIcons.triangleAlert,
    route: '/admin/crisis',
    badgeColor: AppColors.error,
  ),
];

// ─── Sidebar Width ────────────────────────────────────────
const _sidebarExpanded = 240.0;
const _sidebarCollapsed = 72.0;

// ─── Admin Shell ──────────────────────────────────────────

class AdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell>
    with SingleTickerProviderStateMixin {
  bool _collapsed = false;
  late AnimationController _anim;
  late Animation<double> _widthAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _widthAnim = Tween<double>(
      begin: _sidebarExpanded,
      end: _sidebarCollapsed,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic));
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminProvider.notifier).startRealtime();
      ref.read(adminProvider.notifier).loadDashboard();
    });
  }

  @override
  void dispose() {
    ref.read(adminProvider.notifier).stopRealtime();
    _anim.dispose();
    super.dispose();
  }

  void _toggleCollapse() {
    setState(() => _collapsed = !_collapsed);
    _collapsed ? _anim.forward() : _anim.reverse();
  }

  String _currentRoute(BuildContext context) {
    return GoRouterState.of(context).matchedLocation;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    if (isMobile) {
      return _MobileAdminShell(child: widget.child);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────
          AnimatedBuilder(
            animation: _widthAnim,
            builder: (context, _) {
              final adminState = ref.watch(adminProvider);
              final alertCount =
                  adminState.alerts.where((a) => !a.dismissed).length;
              return SizedBox(
                width: _widthAnim.value,
                child: _Sidebar(
                  collapsed: _collapsed,
                  fadeAnim: _fadeAnim,
                  onToggle: _toggleCollapse,
                  currentRoute: _currentRoute(context),
                  userName: user?.displayName ?? 'Admin',
                  userRole: user?.role ?? 'admin',
                  onLogout: () => ref.read(authProvider.notifier).logout(),
                  flaggedCount: adminState.stats.flaggedPosts,
                  crisisCount: adminState.stats.crisisMessages,
                  alertCount: alertCount,
                ),
              );
            },
          ),

          // ── Main Content ─────────────────────────────
          Expanded(
            child: Column(
              children: [
                Consumer(builder: (context, ref, _) {
                  final adminState = ref.watch(adminProvider);
                  return _AdminTopBar(
                    currentRoute: _currentRoute(context),
                    realtimeConnected: adminState.realtimeConnected,
                    alertCount:
                        adminState.alerts.where((a) => !a.dismissed).length,
                    onRefresh: () =>
                        ref.read(adminProvider.notifier).loadDashboard(),
                    lastRefreshed: adminState.stats.lastRefreshed,
                  );
                }),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF5F7FA),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar Widget ───────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final Animation<double> fadeAnim;
  final VoidCallback onToggle;
  final String currentRoute;
  final String userName;
  final String userRole;
  final VoidCallback onLogout;
  final int flaggedCount;
  final int crisisCount;
  final int alertCount;

  const _Sidebar({
    required this.collapsed,
    required this.fadeAnim,
    required this.onToggle,
    required this.currentRoute,
    required this.userName,
    required this.userRole,
    required this.onLogout,
    this.flaggedCount = 0,
    this.crisisCount = 0,
    this.alertCount = 0,
  });

  // Health score: green ≥ 70 alerts, amber ≥ 30, red < 30
  // (We invert alertCount — zero alerts = healthy)
  Color _healthColor() {
    if (alertCount == 0) return AppColors.success;
    if (alertCount <= 2) return AppColors.warning;
    return AppColors.error;
  }

  String _healthLabel() {
    if (alertCount == 0) return 'Healthy';
    if (alertCount <= 2) return 'Warning';
    return 'Critical';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Logo / Brand ───────────────────────────
          _SidebarHeader(
            collapsed: collapsed,
            onToggle: onToggle,
            fadeAnim: fadeAnim,
            healthColor: _healthColor(),
            healthLabel: _healthLabel(),
          ),

          const SizedBox(height: 8),

          // ── Admin Badge ────────────────────────────
          AnimatedBuilder(
            animation: fadeAnim,
            builder: (_, __) => collapsed
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.crown,
                          size: 16, color: Colors.white),
                    ),
                  )
                : Opacity(
                    opacity: fadeAnim.value,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: AppRadius.smAll,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(LucideIcons.crown,
                                size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    userRole.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 4),

          // ── New User Quick Action ──────────────────
          AnimatedBuilder(
            animation: fadeAnim,
            builder: (_, __) => collapsed
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 4),
                    child: _QuickActionIconBtn(
                      icon: LucideIcons.userPlus,
                      onTap: () => context.go('/admin/users'),
                      tooltip: 'New User',
                    ),
                  )
                : Opacity(
                    opacity: fadeAnim.value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: _QuickActionBtn(
                        label: 'New User',
                        icon: LucideIcons.userPlus,
                        onTap: () => context.go('/admin/users'),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 4),

          // ── Nav Items ──────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _navItems.length,
              itemBuilder: (context, i) {
                final item = _navItems[i];
                final isActive = currentRoute.startsWith(item.route);
                int badge = 0;
                if (item.route == '/admin/moderation') badge = flaggedCount;
                if (item.route == '/admin/crisis') badge = crisisCount;
                if (item.route == '/admin/dashboard') badge = alertCount;
                return _NavTile(
                  item: item,
                  isActive: isActive,
                  collapsed: collapsed,
                  onTap: () => context.go(item.route),
                  badgeCount: badge,
                  fadeAnim: fadeAnim,
                );
              },
            ),
          ),

          // ── Divider + Logout ───────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFF1E293B),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _NavTile(
              item: const _NavItem(
                label: 'Back to App',
                icon: LucideIcons.arrowLeft,
                activeIcon: LucideIcons.arrowLeft,
                route: '/home',
              ),
              isActive: false,
              collapsed: collapsed,
              onTap: () => context.go('/home'),
              fadeAnim: fadeAnim,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
            child: _NavTile(
              item: const _NavItem(
                label: 'Sign Out',
                icon: LucideIcons.logOut,
                activeIcon: LucideIcons.logOut,
                route: '',
                badgeColor: AppColors.error,
              ),
              isActive: false,
              collapsed: collapsed,
              onTap: onLogout,
              isDestructive: true,
              fadeAnim: fadeAnim,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar Header ───────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onToggle;
  final Animation<double> fadeAnim;
  final Color healthColor;
  final String healthLabel;

  const _SidebarHeader({
    required this.collapsed,
    required this.onToggle,
    required this.fadeAnim,
    required this.healthColor,
    required this.healthLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.brain, size: 20, color: Colors.white),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedBuilder(
                animation: fadeAnim,
                builder: (_, __) => Opacity(
                  opacity: fadeAnim.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'MindBridge',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Platform health badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: healthColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: healthColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: healthColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  healthLabel,
                                  style: TextStyle(
                                    color: healthColor,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Admin Console',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          IconButton(
            onPressed: onToggle,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                collapsed
                    ? LucideIcons.panelLeftOpen
                    : LucideIcons.panelLeftClose,
                key: ValueKey(collapsed),
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Button (expanded) ──────────────────────

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Action Icon Button (collapsed) ────────────────

class _QuickActionIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _QuickActionIconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.smAll,
        child: InkWell(
          borderRadius: AppRadius.smAll,
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: AppRadius.smAll,
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

// ─── Nav Tile ─────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;
  final bool isDestructive;
  final int badgeCount;
  final Animation<double> fadeAnim;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
    required this.fadeAnim,
    this.isDestructive = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppColors.error
        : isActive
            ? AppColors.primary
            : Colors.white.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: collapsed ? item.label : '',
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.smAll,
          child: InkWell(
            borderRadius: AppRadius.smAll,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: AppRadius.smAll,
                border: isActive
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 18,
                        color: color,
                      ),
                      // Small dot badge when collapsed
                      if (collapsed && badgeCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: item.badgeColor ?? AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: fadeAnim,
                        builder: (_, __) => Opacity(
                          opacity: fadeAnim.value,
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: color,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: fadeAnim,
                      builder: (_, __) => Opacity(
                        opacity: fadeAnim.value,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (badgeCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.badgeColor ?? AppColors.error,
                                  borderRadius: AppRadius.pillAll,
                                ),
                                child: Text(
                                  badgeCount > 99
                                      ? '99+'
                                      : badgeCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else if (isActive)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (item.shortcut.isNotEmpty && !isActive) ...[
                              const SizedBox(width: 4),
                              Text(
                                item.shortcut,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────

class _AdminTopBar extends ConsumerStatefulWidget {
  final String currentRoute;
  final bool realtimeConnected;
  final int alertCount;
  final VoidCallback onRefresh;
  final DateTime lastRefreshed;

  const _AdminTopBar({
    required this.currentRoute,
    this.realtimeConnected = false,
    this.alertCount = 0,
    required this.onRefresh,
    required this.lastRefreshed,
  });

  @override
  ConsumerState<_AdminTopBar> createState() => _AdminTopBarState();
}

class _AdminTopBarState extends ConsumerState<_AdminTopBar> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  bool _searchOpen = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String get _pageTitle {
    if (widget.currentRoute.contains('/dashboard')) return 'Dashboard';
    if (widget.currentRoute.contains('/users')) return 'User Management';
    if (widget.currentRoute.contains('/moderation')) return 'Content Moderation';
    if (widget.currentRoute.contains('/crisis')) return 'Crisis Monitor';
    if (widget.currentRoute.contains('/analytics')) return 'Analytics';
    if (widget.currentRoute.contains('/broadcast')) return 'Broadcast';
    if (widget.currentRoute.contains('/settings')) return 'Settings';
    return 'Admin Console';
  }

  String _lastUpdatedLabel() {
    final diff = _now.difference(widget.lastRefreshed);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}  $h:$m $ampm';
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Text(
                _pageTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),

              // Alert badge
              if (widget.alertCount > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: AppRadius.pillAll,
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.triangleAlert,
                          size: 12, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.alertCount} alert${widget.alertCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Search button
              _TopBarIconBtn(
                icon: LucideIcons.search,
                tooltip: 'Search',
                onTap: _toggleSearch,
                active: _searchOpen,
              ),
              const SizedBox(width: 4),

              // Refresh button
              _TopBarIconBtn(
                icon: LucideIcons.refreshCw,
                tooltip: 'Refresh data',
                onTap: widget.onRefresh,
              ),
              const SizedBox(width: 12),

              // Live / Connecting badge with last updated
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.realtimeConnected
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: AppRadius.pillAll,
                  border: Border.all(
                    color: widget.realtimeConnected
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulseDot(
                        color: widget.realtimeConnected
                            ? AppColors.success
                            : AppColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      widget.realtimeConnected ? 'Live' : 'Connecting…',
                      style: TextStyle(
                        color: widget.realtimeConnected
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.realtimeConnected) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· ${_lastUpdatedLabel()}',
                        style: TextStyle(
                          color: widget.realtimeConnected
                              ? AppColors.success.withValues(alpha: 0.7)
                              : AppColors.warning.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatTime(_now),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // ── Search Overlay Bar ─────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _searchOpen
              ? Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    border: const Border(
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.search,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText:
                                'Search users, posts, alerts…',
                            hintStyle: TextStyle(
                                color: AppColors.textMuted, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x,
                            size: 16, color: AppColors.textMuted),
                        onPressed: _toggleSearch,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── Top Bar Icon Button ──────────────────────────────────

class _TopBarIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _TopBarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? AppColors.primaryContainer
            : Colors.transparent,
        borderRadius: AppRadius.smAll,
        child: InkWell(
          borderRadius: AppRadius.smAll,
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 16,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pulse Dot ────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _anim.value),
            shape: BoxShape.circle,
          ),
        ),
      );
}

// ─── Mobile Admin Shell ───────────────────────────────────

class _MobileAdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const _MobileAdminShell({required this.child});

  @override
  ConsumerState<_MobileAdminShell> createState() => _MobileAdminShellState();
}

class _MobileAdminShellState extends ConsumerState<_MobileAdminShell>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminProvider.notifier).startRealtime();
      ref.read(adminProvider.notifier).loadDashboard();
    });
  }

  @override
  void dispose() {
    ref.read(adminProvider.notifier).stopRealtime();
    super.dispose();
  }

  String _currentRoute() =>
      GoRouterState.of(context).matchedLocation;

  int _selectedIndex() {
    final r = _currentRoute();
    for (int i = 0; i < _mobileBottomNav.length; i++) {
      if (r.startsWith(_mobileBottomNav[i].route)) return i;
    }
    return 0;
  }

  void _showMoreSheet(BuildContext context, AdminState adminState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoreBottomSheet(
        currentRoute: _currentRoute(),
        adminState: adminState,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);
    final alertCount =
        adminState.alerts.where((a) => !a.dismissed).length;
    final selectedIdx = _selectedIndex();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.brain,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Admin',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            // Live dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: adminState.realtimeConnected
                    ? AppColors.success
                    : AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        actions: [
          if (alertCount > 0)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.triangleAlert,
                      color: Colors.white, size: 20),
                  onPressed: () => context.go('/admin/dashboard'),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF0F172A), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        alertCount > 9 ? '9+' : alertCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(LucideIcons.logOut,
                color: Colors.white54, size: 20),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: widget.child,
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => ref.read(adminProvider.notifier).loadDashboard(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Refresh data',
        child: const Icon(LucideIcons.refreshCw, size: 18),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: const Border(
            top: BorderSide(color: Color(0xFF1E293B)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                // Four main nav items
                ..._mobileBottomNav.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isActive = selectedIdx == i;
                  int badge = 0;
                  if (item.route == '/admin/moderation')
                    badge = adminState.stats.flaggedPosts;
                  if (item.route == '/admin/crisis')
                    badge = adminState.stats.crisisMessages;
                  return Expanded(
                    child: _MobileNavItem(
                      item: item,
                      isActive: isActive,
                      badge: badge,
                      onTap: () => context.go(item.route),
                    ),
                  );
                }),
                // "More" item
                Expanded(
                  child: _MobileMoreItem(
                    onTap: () => _showMoreSheet(context, adminState),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mobile Nav Item ──────────────────────────────────────

class _MobileNavItem extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final int badge;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.item,
    required this.isActive,
    required this.badge,
    required this.onTap,
  });

  @override
  State<_MobileNavItem> createState() => _MobileNavItemState();
}

class _MobileNavItemState extends State<_MobileNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward().then((_) {
      _ctrl.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Icon(
                    widget.isActive
                        ? widget.item.activeIcon
                        : widget.item.icon,
                    size: 20,
                    color: color,
                  ),
                ),
                if (widget.badge > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: widget.item.badgeColor ?? AppColors.error,
                        borderRadius: AppRadius.pillAll,
                        border: Border.all(
                            color: const Color(0xFF0F172A), width: 1.5),
                      ),
                      child: Text(
                        widget.badge > 99 ? '99+' : widget.badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.item.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: widget.isActive
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mobile "More" Item ───────────────────────────────────

class _MobileMoreItem extends StatelessWidget {
  final VoidCallback onTap;
  const _MobileMoreItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.ellipsis,
              size: 20, color: Colors.white.withValues(alpha: 0.45)),
          const SizedBox(height: 2),
          Text(
            'More',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── More Bottom Sheet ────────────────────────────────────

class _MoreBottomSheet extends StatelessWidget {
  final String currentRoute;
  final AdminState adminState;

  const _MoreBottomSheet({
    required this.currentRoute,
    required this.adminState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: AppRadius.pillAll,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'All Sections',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ..._navItems.map((item) {
              final isActive = currentRoute.startsWith(item.route);
              int badge = 0;
              if (item.route == '/admin/moderation')
                badge = adminState.stats.flaggedPosts;
              if (item.route == '/admin/crisis')
                badge = adminState.stats.crisisMessages;
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    size: 18,
                    color: isActive
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: badge > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.badgeColor ?? AppColors.error,
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(
                          badge > 99 ? '99+' : badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : isActive
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                onTap: () {
                  Navigator.pop(context);
                  context.go(item.route);
                },
              );
            }),
            // Back to App
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(LucideIcons.arrowLeft,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.55)),
              ),
              title: Text(
                'Back to App',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                context.go('/home');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
