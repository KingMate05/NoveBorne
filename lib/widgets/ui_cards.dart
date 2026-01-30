import 'package:flutter/material.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    required this.background,
    required this.borderColor,
  });

  final Widget child;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class OutlinedCard extends StatelessWidget {
  const OutlinedCard({
    super.key,
    required this.child,
    required this.borderColor,
  });

  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.6),
      ),
      child: child,
    );
  }
}

class InkCard extends StatelessWidget {
  const InkCard({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: child,
      ),
    );
  }
}
