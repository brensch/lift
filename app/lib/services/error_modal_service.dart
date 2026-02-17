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
    unawaited(
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      ).whenComplete(() {
        _isShowing = false;
      }),
    );
  }
}
