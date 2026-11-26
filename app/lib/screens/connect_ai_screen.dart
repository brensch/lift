/// The menu's Connect AI: what setup's bot step says, on a page of its own.
library;

import 'package:material_ui/material_ui.dart';

import '../gen/copy.dart';
import '../theme/theme_spec.dart';
import '../widgets/common/flat.dart';
import '../widgets/connect_ai.dart';

class ConnectAiScreen extends StatelessWidget {
  const ConnectAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final t = copy.onboarding.bot;
    return Scaffold(
      appBar: AppBar(title: PageTitle(copy.connectAi.title)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          FlatSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: TextStyle(
                    fontSize: tk.size.headline,
                    fontWeight: tk.weight.heavy,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t.body,
                  style: TextStyle(
                    fontSize: tk.size.body,
                    height: 1.4,
                    color: tk.muted,
                  ),
                ),
              ],
            ),
          ),
          const ConnectAiSteps(),
        ],
      ),
    );
  }
}
