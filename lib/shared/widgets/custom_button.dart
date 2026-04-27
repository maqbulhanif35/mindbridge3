import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ─── Primary Gradient Button ──────────────────────────────

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final double? width;
  final double height;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
    this.height = 56,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isLoading && !isDisabled && onTap != null;
    final theme = Theme.of(context);
    final bgColor = isEnabled ? (color ?? theme.colorScheme.primary) : theme.disabledColor;
    final fgColor = isEnabled ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withOpacity(0.38);

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: theme.colorScheme.onSurface, width: 2),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(fgColor),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: fgColor, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: fgColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Secondary Outlined Button ────────────────────────────

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double? width;
  final Color? color;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.width,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: c, width: 2),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: c, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Icon Action Button ───────────────────────────────────

class IconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final String? tooltip;

  const IconActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color,
    this.backgroundColor,
    this.size = 44,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final widget = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: theme.colorScheme.onSurface, width: 1.5),
        ),
        child: Icon(
          icon,
          color: color ?? theme.colorScheme.onSurface,
          size: size * 0.5,
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: widget);
    }
    return widget;
  }
}

// ─── Crisis SOS Button ────────────────────────────────────

class SosButton extends StatelessWidget {
  final VoidCallback onTap;
  const SosButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: theme.colorScheme.onSurface, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_rounded, color: theme.colorScheme.onError, size: 32),
            const SizedBox(height: 4),
            Text(
              'SOS',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: theme.colorScheme.onError,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
