import 'dart:async' show unawaited;
import 'package:flutter/material.dart';

class ErrorModalService {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static bool _isShowing = false;

  static void showError(String message, {String title = 'Error'}) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || _isShowing) return;

    _isShowing = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      _isShowing = false;
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$title: $message'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

    // Prevent snackbar spam from back-to-back failures.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 600)).then((_) {
        _isShowing = false;
      }),
    );
  }
}
