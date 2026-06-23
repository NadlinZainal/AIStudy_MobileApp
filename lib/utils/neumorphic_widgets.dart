import 'package:flutter/material.dart';

class NeumorphicStyle {
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFF6366F1);
  static const shadowLight = Color(0xFFFFFFFF);
  static const shadowDark = Color(0xFFE2E8F0);
  static const borderRadius = BorderRadius.all(Radius.circular(24));

  static BoxDecoration surfaceDecoration(
      {Color? color, BorderRadius? radius, bool isDark = false}) {
    final backgroundColor =
        color ?? (isDark ? const Color(0xFF1E293B) : surface);
    final topShadow = isDark ? Colors.white.withValues(alpha: 0.04) : shadowLight;
    final bottomShadow = isDark ? Colors.black.withValues(alpha: 0.3) : shadowDark;
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: radius ?? borderRadius,
      boxShadow: [
        BoxShadow(
          color: topShadow,
          offset: Offset(-10, -10),
          blurRadius: 24,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: bottomShadow,
          offset: Offset(10, 10),
          blurRadius: 24,
          spreadRadius: 0,
        ),
      ],
    );
  }
}

class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin = const EdgeInsets.all(0),
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: NeumorphicStyle.surfaceDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        isDark: isDark,
        radius: borderRadius ?? NeumorphicStyle.borderRadius,
      ),
      child: child,
    );
  }
}

class NeumorphicButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;

  const NeumorphicButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = backgroundColor ?? Theme.of(context).colorScheme.surface;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null ? 0.65 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius ?? NeumorphicStyle.borderRadius,
          splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Container(
            padding: padding,
            decoration: NeumorphicStyle.surfaceDecoration(
              color: color,
              isDark: isDark,
              radius: borderRadius ?? NeumorphicStyle.borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class NeumorphicLoader extends StatelessWidget {
  final String label;

  const NeumorphicLoader({
    super.key,
    this.label = 'Loading…',
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          const SizedBox(
            height: 48,
            width: 48,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class NeumorphicEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const NeumorphicEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        NeumorphicContainer(
          padding: const EdgeInsets.all(24),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(32),
          child: Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }
}
