import 'package:flutter/material.dart';

/// The app's messenger: the one place a short message is shown from, so it
/// can be said from a provider with no context of its own. The app's
/// `MaterialApp` is given this key.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// A short message over the app, drawn by the app itself in its own face
/// and colours (the theme's snack bar), over whatever page is on show. It
/// was the phone's own toast, which on Android is the system's grey pill
/// with the app's icon in it, whatever colours it is asked for.
///
/// [backgroundColor] and [textColor] say what kind of message it is (the
/// callers pass the theme's); with no app on screen there is nowhere to
/// show it and nothing happens.
void showToast({
  required String msg,
  required Color backgroundColor,
  required Color textColor,
}) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: textColor)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}
