import 'dart:io' show Platform;
import '../widgets/common/flat.dart';
import '../widgets/common/quiet_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../services/wearable_bridge_service.dart';
import '../theme/theme_spec.dart';

const _gitHash = String.fromEnvironment('GIT_HASH', defaultValue: 'dev');

class BuildInfoScreen extends StatefulWidget {
  const BuildInfoScreen({super.key});

  @override
  State<BuildInfoScreen> createState() => _BuildInfoScreenState();
}

class _BuildInfoScreenState extends State<BuildInfoScreen> {
  PackageInfo? _packageInfo;
  Map<String, String> _deviceInfo = {};
  bool _watchAvailable = false;
  WatchClockSync? _clockSync;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wearBridge = context.read<WearableBridgeService>();
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = await _getDeviceInfo();
    final watchAvailable = await wearBridge.isWatchAppAvailable();
    WatchClockSync? clockSync;
    if (watchAvailable) {
      clockSync = await wearBridge.getWatchClockSync();
    }
    if (!mounted) return;
    setState(() {
      _packageInfo = packageInfo;
      _deviceInfo = deviceInfo;
      _watchAvailable = watchAvailable;
      _clockSync = clockSync;
      _loaded = true;
    });
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return {
        'Device': '${info.manufacturer} ${info.model}',
        'Android version':
            '${info.version.release} (SDK ${info.version.sdkInt})',
        'Security patch': info.version.securityPatch ?? 'unknown',
      };
    } else if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return {
        'Device': '${info.name} (${info.model})',
        'iOS version': info.systemVersion,
      };
    }
    return {'Platform': Platform.operatingSystem};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: PageTitle('Build info')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              // A pixel on top: room for the first heading band's top line.
              padding: const EdgeInsets.only(top: 1, bottom: 24),
              children: [
                _Section(
                  title: 'App',
                  entries: {
                    'Version':
                        '${_packageInfo?.version ?? '?'} (${_packageInfo?.buildNumber ?? '?'})',
                    'Git hash': _gitHash,
                    'Package': _packageInfo?.packageName ?? '?',
                    'Server': _serverInfo,
                  },
                ),
                _Section(title: 'Device', entries: _deviceInfo),
                _Section(
                  title: 'Watch',
                  entries: {
                    'Installed': _watchAvailable ? 'Yes' : 'No',
                    if (_clockSync != null) ...{
                      'Clock delta': '${_clockSync!.deltaMs}ms',
                      'Round trip': '${_clockSync!.roundTripMs}ms',
                    },
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: QuietLink(
                    label: 'Copy to clipboard',
                    onPressed: () {
                      final buf = StringBuffer();
                      buf.writeln(
                        'Version: ${_packageInfo?.version} (${_packageInfo?.buildNumber})',
                      );
                      buf.writeln('Git: $_gitHash');
                      buf.writeln('Package: ${_packageInfo?.packageName}');
                      buf.writeln('Server: $_serverInfo');
                      for (final e in _deviceInfo.entries) {
                        buf.writeln('${e.key}: ${e.value}');
                      }
                      buf.writeln('Watch installed: $_watchAvailable');
                      if (_clockSync != null) {
                        buf.writeln('Clock delta: ${_clockSync!.deltaMs}ms');
                        buf.writeln('Round trip: ${_clockSync!.roundTripMs}ms');
                      }
                      Clipboard.setData(ClipboardData(text: buf.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String get _serverInfo {
    const host = String.fromEnvironment('SERVER_HOST', defaultValue: '');
    const port = String.fromEnvironment('SERVER_PORT', defaultValue: '');
    if (host.isNotEmpty) return '$host:$port';
    return 'default';
  }
}

/// A section: its heading band, then a full-width row a fact, the name on
/// the left and the value on the right.
class _Section extends StatelessWidget {
  final String title;
  final Map<String, String> entries;

  const _Section({required this.title, required this.entries});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlatHeading(title),
        for (final e in entries.entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.hairline)),
            ),
            child: Row(
              children: [
                Text(
                  e.key,
                  style: TextStyle(fontSize: t.size.body, color: t.muted),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    e.value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: t.mono(
                      TextStyle(
                        fontSize: t.size.body,
                        fontWeight: t.weight.bold,
                        color: t.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
