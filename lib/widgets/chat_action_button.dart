import 'package:flutter/material.dart';

class ActionIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;
  final Color? backgroundColor;
  final Widget icon;
  final double angle;

  const ActionIconButton({
    super.key,
    required this.onPressed,
    this.size = 48,
    this.backgroundColor,
    this.angle = 0,
    this.icon = const Icon(Icons.send, color: Colors.white, size: 22),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.colorScheme.secondary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Transform.rotate(
            angle: angle,
            alignment: Alignment.center,
            child: icon,
          ),
        ),
      ),
    );
  }
}
