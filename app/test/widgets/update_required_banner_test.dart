import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/services/account_sync.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/theme/app_theme.dart';
import 'package:schlift/widgets/update_required_banner.dart';

/// An AccountSync the test turns away as too old, as the server would.
class _Sync extends AccountSync {
  _Sync() : super(GrpcClient(host: '127.0.0.1', port: 1));

  bool tooOld = false;

  @override
  bool get updateRequired => tooOld;

  void turnAway() {
    tooOld = true;
    notifyListeners();
  }
}

/// A button that counts its taps, so a lost tap or lost state shows.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => setState(() => taps++),
        child: Text('tapped $taps'),
      ),
    ),
  );
}

void main() {
  testWidgets('a turned-away app shows the banner and stays usable', (
    tester,
  ) async {
    final launched = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url']);
        }
        return true;
      },
    );
    final sync = _Sync();
    await tester.pumpWidget(
      ChangeNotifierProvider<AccountSync>.value(
        value: sync,
        child: MaterialApp(
          theme: AppTheme.theme,
          builder: (context, child) => UpdateRequiredBanner(child: child!),
          home: const _Counter(),
        ),
      ),
    );
    expect(find.text(copy.updateRequired.title), findsNothing);
    await tester.tap(find.text('tapped 0'));
    await tester.pump();

    sync.turnAway();
    await tester.pump();
    expect(find.text(copy.updateRequired.title), findsOneWidget);
    expect(find.text(copy.updateRequired.body), findsOneWidget);

    // The app under it keeps its state and still takes taps.
    await tester.tap(find.text('tapped 1'));
    await tester.pump();
    expect(find.text('tapped 2'), findsOneWidget);

    // The button goes to the store.
    await tester.tap(find.text(copy.updateRequired.button));
    await tester.pump();
    expect(launched, [contains('com.brensch.schlift')]);
  });
}
