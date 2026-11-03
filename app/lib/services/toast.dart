import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:fluttertoast/fluttertoast.dart';

/// A short message over the app: the platform's toast on the phones and the
/// web. Elsewhere — the desktop build the e2e scenarios run — there is no
/// toast, and nothing is shown.
void showToast({
  required String msg,
  required Color backgroundColor,
  required Color textColor,
  Toast toastLength = Toast.LENGTH_SHORT,
  ToastGravity gravity = ToastGravity.BOTTOM,
  double? fontSize,
}) {
  if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) return;
  Fluttertoast.showToast(
    msg: msg,
    toastLength: toastLength,
    gravity: gravity,
    backgroundColor: backgroundColor,
    textColor: textColor,
    fontSize: fontSize,
  );
}
