import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import '../gen/copy.dart';
import '../theme/theme_spec.dart';
import 'app_logger.dart';

class ErrorModalService {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static bool _isShowing = false;

  /// Tell the person something went wrong. Every one is logged as an
  /// error, shown or not (one may already be up), so the log has it.
  static void showError(String message) {
    AppLogger.instance.error('Error', message);
    final context = rootNavigatorKey.currentContext;
    if (context == null || _isShowing) return;

    _isShowing = true;
    unawaited(
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: Text(
            copy.errorDialog.title,
            style: TextStyle(fontWeight: context.tokens.weight.heavy),
          ),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(copy.errorDialog.ok),
            ),
          ],
        ),
      ).whenComplete(() {
        _isShowing = false;
      }),
    );
  }
}
