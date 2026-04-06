import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TopLevelBackScope extends StatelessWidget {
  final Widget child;

  const TopLevelBackScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: child,
    );
  }
}
