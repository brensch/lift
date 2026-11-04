import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Save a file the app made where the person chooses. On Android, the
/// system's "save as" picker (Downloads, a drive); elsewhere the share
/// sheet, whose "Save to Files" is the same thing on iOS. Returns false when
/// they backed out.
class FileSaver {
  static const _channel = MethodChannel('schlift/files');

  static Future<bool> saveAs(File file, String name) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod<bool>('saveAs', {
            'path': file.path,
            'name': name,
          }) ??
          false;
    }
    final shared = await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
    return shared.status == ShareResultStatus.success;
  }
}
