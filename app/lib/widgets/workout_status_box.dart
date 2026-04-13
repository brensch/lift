import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../logic/exercises.dart';
import 'plate_visualization.dart';

class StatusBox extends StatelessWidget {
  final String sideLabel;
  final String? sideBadge;
  final String? header;
  final Color color;
  final Color? sideColor;
  final Widget? child;
  final String? stateLabel;
  final String? timerText;
  final Color? timerColor;
  final ProposedSet? set;
  final bool isComplete;
  final bool showHeader;
  final Widget? headerTrailing;
  final double sideLabelWidth;

  const StatusBox({
    super.key,
    required this.sideLabel,
    this.sideBadge,
    this.header,
    required this.color,
    this.sideColor,
    this.child,
    this.stateLabel,
    this.timerText,
    this.timerColor,
    this.set,
    this.isComplete = false,
    this.showHeader = false,
    this.headerTrailing,
    this.sideLabelWidth = 32,
  });

  @override
  Widget build(BuildContext context) {
    final name = set != null ? (exerciseNames[set!.exercise] ?? '?') : null;
    final sidebarColor = sideColor ?? color;
    final contentColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final accentColor = contentColor.withValues(alpha: 0.82);
    final dividerColor = contentColor.withValues(alpha: 0.22);
    final sidebarContentColor =
        ThemeData.estimateBrightnessForColor(sidebarColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final effectiveTimerColor =
        timerColor != null &&
            (timerColor!.toARGB32() == color.toARGB32() ||
                timerColor!.computeLuminance() == color.computeLuminance())
        ? contentColor
        : (timerColor ?? contentColor);

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: sideLabelWidth,
                color: sidebarColor,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: sideBadge != null
                      ? Text(
                          sideBadge!,
                          style: const TextStyle(fontSize: 24, height: 1),
                        )
                      : RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            sideLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              color: sidebarContentColor.withValues(
                                alpha: 0.82,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                ),
              ),
              Container(width: 1, color: dividerColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (header != null && showHeader) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                header!,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: accentColor,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (headerTrailing != null) ...[
                              const SizedBox(width: 8),
                              headerTrailing!,
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (name != null) ...[
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                      color: contentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                if (set != null) ...[
                                  StatusSetWeightInfo(
                                    set: set!,
                                    textColor: contentColor,
                                    secondaryTextColor: accentColor,
                                  ),
                                ] else if (isComplete) ...[
                                  Text(
                                    'All sets complete',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'monospace',
                                      color: contentColor,
                                    ),
                                  ),
                                ] else if (child != null) ...[
                                  child!,
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (stateLabel != null) ...[
                                Text(
                                  stateLabel!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              if (timerText != null)
                                Text(
                                  timerText!,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    letterSpacing: -1.5,
                                    height: 1.0,
                                    color: effectiveTimerColor,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusSetWeightInfo extends StatelessWidget {
  final ProposedSet set;
  final Color textColor;
  final Color secondaryTextColor;

  const StatusSetWeightInfo({
    super.key,
    required this.set,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<SettingsProvider>().weightUnit;
    final weightText = formatWeight(set.targetWeight.toDouble(), unit);
    void detailTrigger() {
      showPlateBreakdownDialog(context, weight: set.targetWeight.toDouble());
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            set.isAmrap
                ? 'AMRAP\u00D7$weightText'
                : '${set.targetReps}\u00D7$weightText',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: -1.5,
              height: 1.0,
            ).copyWith(color: textColor),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              weightUnitSuffix(unit),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: detailTrigger,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: secondaryTextColor.withValues(alpha: 0.85),
                    width: 1.2,
                  ),
                ),
                child: SizedBox(
                  width: 92,
                  height: 32,
                  child: Center(
                    child: PlateVisualization(
                      weight: set.targetWeight.toDouble(),
                      scale: 0.72,
                      isInteractive: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
