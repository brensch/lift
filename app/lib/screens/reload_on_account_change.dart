/// A screen that reads the account and reads it again when another
/// device's changes (or a seeded history) arrive while it is open.
library;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/account_sync.dart';

mixin ReloadOnAccountChange<T extends StatefulWidget> on State<T> {
  late final AccountSync _sync = context.read<AccountSync>();
  late int _revision = _sync.revision;

  /// Read the account again.
  void reload();

  void _onSync() {
    if (_sync.revision == _revision) return;
    _revision = _sync.revision;
    reload();
  }

  @override
  void initState() {
    super.initState();
    _sync.addListener(_onSync);
  }

  @override
  void dispose() {
    _sync.removeListener(_onSync);
    super.dispose();
  }
}
