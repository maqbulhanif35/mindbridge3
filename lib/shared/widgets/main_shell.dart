import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/router/app_router.dart';
import 'achievement_overlay.dart';

// ─── Main Shell ───────────────────────────────────────────
// StatelessWidget + GoRouterState.of(context) creates an InheritedWidget
// dependency that automatically rebuilds the shell on every route change.
// Do NOT add a routerDelegate listener here — it causes double-rebuilds that
// interrupt page transition animations.

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith(AppRoutes.chat)) return 1;
    if (loc.startsWith('/mood')) return 2;
    if (loc.startsWith(AppRoutes.journal)) return 3;
    if (loc.startsWith(AppRoutes.mindfulness) ||
        loc.startsWith(AppRoutes.resources) ||
        loc.startsWith(AppRoutes.community) ||
        loc.startsWith(AppRoutes.wellness)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(context);
    return AchievementOverlay(
      child: Scaffold(
        extendBody: false,
        body: child,
        bottomNavigationBar: _LiquidNavBar(
          selectedIndex: idx,
          onTap: (i) {
            HapticFeedback.lightImpact();
            switch (i) {
              case 0: context.go(AppRoutes.home);
              case 1: context.go(AppRoutes.chat);
              case 2: context.go(AppRoutes.moodTracker);
              case 3: context.go(AppRoutes.journal);
              case 4: context.go(AppRoutes.mindfulness);
            }
          },
        ),
      ),
    );
  }
}

// ─── Nav Item Data ────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─── Liquid Nav Bar ───────────────────────────────────────

class _LiquidNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _LiquidNavBar({required this.selectedIndex, required this.onTap});

  static const _kItems = [
    _NavItem(icon: LucideIcons.house, label: 'Home'),
    _NavItem(icon: LucideIcons.messageCircle, label: 'Maya'),
    _NavItem(icon: LucideIcons.smile, label: 'Mood'),
    _NavItem(icon: LucideIcons.bookOpen, label: 'Journal'),
    _NavItem(icon: LucideIcons.compass, label: 'Explore'),
  ];

  @override
  State<_LiquidNavBar> createState() => _LiquidNavBarState();
}

class _LiquidNavBarState extends State<_LiquidNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _prevIdx = 0;

  @override
  void initState() {
    super.initState();
    _prevIdx = widget.selectedIndex;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(_LiquidNavBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _prevIdx = old.selectedIndex;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (ctx, box) {
              final totalW = box.maxWidth;
              final itemW = totalW / _LiquidNavBar._kItems.length;
              const bubbleD = 42.0;
              const topPad = 4.0;

              return AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final t = Curves.easeOutBack
                      .transform(_ctrl.value.clamp(0.0, 1.0));
                  final stretch =
                      1.0 + 0.35 * math.sin(math.pi * _ctrl.value);
                  final fromCx = _prevIdx * itemW + itemW / 2;
                  final toCx = widget.selectedIndex * itemW + itemW / 2;
                  final cx = fromCx + (toCx - fromCx) * t;
                  final bubbleW =
                      (bubbleD * stretch).clamp(bubbleD, bubbleD * 1.6);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ── Bubble indicator ──────────────────
                      Positioned(
                        left: cx - bubbleW / 2,
                        top: topPad,
                        child: Container(
                          width: bubbleW,
                          height: bubbleD,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(bubbleD / 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.30),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _LiquidNavBar
                                  ._kItems[widget.selectedIndex].icon,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),

                      // ── Tap targets ───────────────────────
                      Row(
                        children: List.generate(
                          _LiquidNavBar._kItems.length,
                          (i) {
                            final isSelected = i == widget.selectedIndex;
                            final item = _LiquidNavBar._kItems[i];
                            return Expanded(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => widget.onTap(i),
                                  behavior: HitTestBehavior.opaque,
                                  child: SizedBox(
                                    height: 64,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: topPad),
                                        SizedBox(
                                          height: bubbleD,
                                          child: isSelected
                                              ? const SizedBox()
                                              : Center(
                                                  child: _BounceIcon(
                                                    icon: item.icon,
                                                    color: isDark
                                                        ? AppColors
                                                            .textMutedDark
                                                        : AppColors.textMuted,
                                                    onTap: () => widget.onTap(i),
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(height: 1),
                                        AnimatedOpacity(
                                          opacity: isSelected ? 1.0 : 0.0,
                                          duration: const Duration(
                                              milliseconds: 180),
                                          child: Text(
                                            item.label,
                                            style: const TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Bounce Icon ─────────────────────────────────────────

class _BounceIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _BounceIcon({required this.icon, required this.color, this.onTap});

  @override
  State<_BounceIcon> createState() => _BounceIconState();
}

class _BounceIconState extends State<_BounceIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.80).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _bounce() => _ctrl.forward().then((_) { if (mounted) _ctrl.reverse(); });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _bounce(),
      onTap: widget.onTap,
      behavior: HitTestBehavior.translucent,
      child: ScaleTransition(
        scale: _scale,
        child: Icon(widget.icon, size: 22, color: widget.color),
      ),
    );
  }
}
