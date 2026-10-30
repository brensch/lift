package com.brensch.schlift.wear

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.HourglassBottom
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import workout.v1.Wearable
import workout.v1.WorkoutOuterClass

// One spec for every screen (docs/plans/one-tap-sets.md, 8.1): vertical,
// full-bleed, black. One status row at the top, one primary number, one
// primary action, everything else small and grey. The watch lays out strings
// the phone rendered; it never derives text from the workout.

internal val WearBodyFontFamily =
    FontFamily(
        Font(R.font.manrope_variable, weight = FontWeight.Normal),
        Font(R.font.manrope_variable, weight = FontWeight.Medium),
        Font(R.font.manrope_variable, weight = FontWeight.SemiBold),
        Font(R.font.manrope_variable, weight = FontWeight.Bold),
    )

internal val WearDisplayFontFamily =
    FontFamily(
        Font(R.font.space_grotesk_variable, weight = FontWeight.Medium),
        Font(R.font.space_grotesk_variable, weight = FontWeight.Bold),
    )

internal object WearPalette {
    val Background = Color.Black
    val Text = Color.White
    val Muted = Color(0xFF9CA3AF)
    val Resting = Color(0xFF3B82F6)
    val Yapping = Color(0xFFD94F8C)
    val Lifting = Color(0xFFFF4F00)
    val Done = Color(0xFF16A34A)
}

/** What the status row prints. [ambient] hides the row and every countdown. */
internal data class WearStatus(
    val elapsedText: String,
    val bpm: Float?,
    val nextUpEmoji: String,
    val ambient: Boolean,
)

// Round faces: content near the top and bottom edges has less width, so the
// insets are fractions of the face rather than fixed dp. The status row sits
// where the chord at the *top* of its 16sp glyphs is still ~58% of the face
// wide (the display mask cuts anything outside the circle); the body inset
// and bottom pad keep a full-width pill button's rounded ends inside the
// circle, including the thinner 44dp effort pills, whose ends reach further
// into the corner.
private const val STATUS_TOP_FRACTION = 0.10f
private const val STATUS_INSET_FRACTION = 0.21f
private const val BODY_INSET_FRACTION = 0.14f
private const val BODY_BOTTOM_FRACTION = 0.12f
private val StatusRowHeight = 20.dp

// Spec sizes assume a face tall enough for them. On a smaller face the body
// scales down uniformly so the hierarchy survives instead of clipping.
private const val MIN_BODY_SCALE = 0.6f

@Composable
fun AutoResizingText(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
    fontSize: TextUnit = 16.sp,
    fontWeight: FontWeight? = null,
    fontFamily: FontFamily? = null,
    textAlign: TextAlign? = null,
    overflow: TextOverflow = TextOverflow.Clip,
    maxLines: Int = Int.MAX_VALUE,
    minFontSize: TextUnit = 8.sp,
) {
    var currentFontSize by remember(text, fontSize) { mutableStateOf(fontSize) }
    var readyToDraw by remember(text, fontSize) { mutableStateOf(false) }

    Text(
        text = text,
        modifier =
            modifier.drawWithContent {
                if (readyToDraw) drawContent()
            },
        color = color,
        fontSize = currentFontSize,
        fontWeight = fontWeight,
        fontFamily = fontFamily,
        textAlign = textAlign,
        overflow = overflow,
        softWrap = maxLines > 1,
        maxLines = maxLines,
        onTextLayout = { textLayoutResult ->
            if (textLayoutResult.hasVisualOverflow && currentFontSize > minFontSize) {
                currentFontSize = (currentFontSize.value * 0.9f).sp
            } else {
                readyToDraw = true
            }
        },
    )
}

/**
 * The shell every workout screen shares: status row on top, then the body.
 * [designBodyHeight] is what the body needs at spec sizes; the body receives
 * a scale factor of 1 when it fits and less when the face is shorter. The
 * effort question is the one screen without the row ([showStatusRow]); its
 * first line already carries the countdown and the three buttons need the
 * height.
 */
@Composable
private fun Screen(
    status: WearStatus,
    designBodyHeight: Dp,
    showStatusRow: Boolean = true,
    body: @Composable ColumnScope.(scale: Float) -> Unit,
) {
    BoxWithConstraints(
        modifier =
            Modifier
                .fillMaxSize()
                .background(WearPalette.Background),
    ) {
        val statusTop = maxHeight * STATUS_TOP_FRACTION
        val statusInset = maxWidth * STATUS_INSET_FRACTION
        val bodyInset = maxWidth * BODY_INSET_FRACTION
        val bodyBottom = maxHeight * BODY_BOTTOM_FRACTION
        // Without the status row the body starts where the row would have, so
        // its first line keeps the same clearance from the top of the circle.
        val bodyTop = if (showStatusRow) 0.dp else statusTop
        val statusHeight = if (showStatusRow) StatusRowHeight else 0.dp
        val bodyHeight = maxHeight - statusTop - statusHeight - bodyBottom
        val scale = (bodyHeight / designBodyHeight).coerceIn(MIN_BODY_SCALE, 1f)
        Column(modifier = Modifier.fillMaxSize()) {
            if (showStatusRow) {
                StatusRow(
                    status = status,
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(top = statusTop, start = statusInset, end = statusInset)
                            .heightIn(min = StatusRowHeight),
                )
            }
            Column(
                modifier =
                    Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .padding(top = bodyTop, start = bodyInset, end = bodyInset, bottom = bodyBottom),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                body(scale)
            }
        }
    }
}

/** Elapsed time left, heart rate right in its band colour. A spacer in ambient. */
@Composable
private fun StatusRow(
    status: WearStatus,
    modifier: Modifier,
) {
    if (status.ambient) {
        Spacer(modifier = modifier)
        return
    }
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StatusItem(icon = Icons.Filled.HourglassBottom, text = status.elapsedText, color = WearPalette.Muted)
        Spacer(modifier = Modifier.weight(1f))
        if (status.nextUpEmoji.isNotEmpty()) {
            Text(text = status.nextUpEmoji, fontSize = 14.sp, maxLines = 1)
            Spacer(modifier = Modifier.weight(1f))
        }
        StatusItem(
            icon = Icons.Filled.Favorite,
            text = status.bpm?.let { "${it.toInt()}" } ?: "--",
            color = heartRateColor(status.bpm),
        )
    }
}

@Composable
private fun StatusItem(
    icon: ImageVector,
    text: String,
    color: Color,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(14.dp),
        )
        Spacer(modifier = Modifier.width(3.dp))
        Text(
            text = text,
            color = color,
            fontSize = 16.sp,
            fontFamily = WearDisplayFontFamily,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
        )
    }
}

/** No snapshot, or the workout is over: one grey line. */
@Composable
internal fun IdleScreen() {
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(WearPalette.Background)
                .padding(horizontal = 24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Open Schlift on your phone",
            color = WearPalette.Muted,
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
            maxLines = 2,
        )
    }
}

/** READY: the next set and Start. */
@Composable
internal fun ReadyScreen(
    status: WearStatus,
    exerciseName: String,
    setText: String,
    setLine: String,
    startSet: Wearable.WearAction?,
    actionsEnabled: Boolean,
    onAction: (Wearable.WearAction) -> Unit,
) {
    Screen(status = status, designBodyHeight = 172.dp) { scale ->
        Column(
            modifier =
                Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            AutoResizingText(
                text = exerciseName,
                color = WearPalette.Text,
                fontSize = 18.sp * scale,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                maxLines = 1,
                minFontSize = 11.sp,
                modifier = Modifier.fillMaxWidth(),
            )
            AutoResizingText(
                text = setText,
                color = WearPalette.Text,
                fontSize = 34.sp * scale,
                fontWeight = FontWeight.Bold,
                fontFamily = WearDisplayFontFamily,
                textAlign = TextAlign.Center,
                maxLines = 1,
                modifier = Modifier.fillMaxWidth(),
            )
            AutoResizingText(
                text = setLine,
                color = WearPalette.Muted,
                fontSize = 14.sp * scale,
                textAlign = TextAlign.Center,
                maxLines = 1,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        Spacer(modifier = Modifier.height(8.dp * scale))
        PrimaryButton(
            label = startSet?.label ?: "Start",
            enabled = actionsEnabled && startSet != null,
            onClick = { startSet?.let(onAction) },
            scale = scale,
        )
    }
}

/**
 * After a set: RESTING counts down in blue, then YAPPING counts up in pink
 * once the rest has run out. The timer is the biggest thing; Start lifts
 * the next set, early or late.
 */
@Composable
internal fun RestScreen(
    status: WearStatus,
    timer: RestTimer,
    label: String,
    nextSetText: String,
    startSet: Wearable.WearAction?,
    actionsEnabled: Boolean,
    onAction: (Wearable.WearAction) -> Unit,
) {
    val timerColor = if (timer.countingUp) WearPalette.Yapping else WearPalette.Resting
    Screen(status = status, designBodyHeight = 144.dp) { scale ->
        Column(
            modifier =
                Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            TimerBlock(text = timer.text, label = label, color = timerColor, ambient = status.ambient, scale = scale)
            if (nextSetText.isNotEmpty()) {
                AutoResizingText(
                    text = "Next: $nextSetText",
                    color = WearPalette.Text,
                    fontSize = 14.sp * scale,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
        if (startSet != null) {
            Spacer(modifier = Modifier.height(8.dp * scale))
            PrimaryButton(
                label = startSet.label,
                enabled = actionsEnabled,
                onClick = { onAction(startSet) },
                scale = scale,
                height = 48.dp,
            )
        }
    }
}

/**
 * LIFTING: the set in progress, counting up in orange from Start, and its
 * finishes. Most sets have one (Done); a finding-weight rung three (how many
 * reps were left), each logging the rung and answering for it in one tap.
 */
@Composable
internal fun LiftingScreen(
    status: WearStatus,
    timerText: String,
    label: String,
    exerciseName: String,
    setText: String,
    finishes: List<Wearable.WearAction>,
    actionsEnabled: Boolean,
    onAction: (Wearable.WearAction) -> Unit,
) {
    Screen(status = status, designBodyHeight = 160.dp) { scale ->
        Column(
            modifier =
                Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            TimerBlock(text = timerText, label = label, color = WearPalette.Lifting, ambient = status.ambient, scale = scale)
            AutoResizingText(
                text = if (setText.isEmpty()) exerciseName else "$exerciseName $setText",
                color = WearPalette.Text,
                fontSize = 14.sp * scale,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                maxLines = 1,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        Spacer(modifier = Modifier.height(8.dp * scale))
        if (finishes.size == 1) {
            PrimaryButton(
                label = finishes.single().label,
                enabled = actionsEnabled,
                onClick = { onAction(finishes.single()) },
                scale = scale,
                height = 48.dp,
            )
        } else {
            FinishRow(finishes = finishes, actionsEnabled = actionsEnabled, onAction = onAction, scale = scale)
        }
    }
}

/** A big timer over its state label, both in the state's colour. */
@Composable
private fun TimerBlock(
    text: String,
    label: String,
    color: Color,
    ambient: Boolean,
    scale: Float,
) {
    if (!ambient && text.isNotEmpty()) {
        AutoResizingText(
            text = text,
            color = color,
            fontSize = 40.sp * scale,
            fontWeight = FontWeight.Bold,
            fontFamily = WearDisplayFontFamily,
            textAlign = TextAlign.Center,
            maxLines = 1,
            modifier = Modifier.fillMaxWidth(),
        )
    }
    if (label.isNotEmpty()) {
        AutoResizingText(
            text = label,
            color = color,
            fontSize = 14.sp * scale,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
            maxLines = 1,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/** ALL_DONE: the summary and End workout while the phone still offers it. */
@Composable
internal fun DoneScreen(
    status: WearStatus,
    summary: Wearable.WearCompletionSummary?,
    endWorkout: Wearable.WearAction?,
    actionsEnabled: Boolean,
    onAction: (Wearable.WearAction) -> Unit,
) {
    // Title 34 + summary 23, button 56 at spec sizes.
    Screen(status = status, designBodyHeight = 113.dp) { scale ->
        Column(
            modifier =
                Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Done",
                color = WearPalette.Done,
                fontSize = 26.sp * scale,
                fontWeight = FontWeight.Bold,
                fontFamily = WearDisplayFontFamily,
                maxLines = 1,
            )
            if (summary != null) {
                Spacer(modifier = Modifier.height(4.dp * scale))
                AutoResizingText(
                    text = formatSummaryLine(summary),
                    color = WearPalette.Muted,
                    fontSize = 14.sp * scale,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
        if (endWorkout != null) {
            Spacer(modifier = Modifier.height(8.dp * scale))
            PrimaryButton(
                label = endWorkout.label,
                enabled = actionsEnabled,
                onClick = { onAction(endWorkout) },
                scale = scale,
                height = 48.dp,
            )
        }
    }
}

// ── Shared button styles ──

/** The one primary action on a screen: full width, white, black bold text. */
@Composable
private fun PrimaryButton(
    label: String,
    enabled: Boolean,
    onClick: () -> Unit,
    scale: Float,
    height: Dp = 56.dp,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier =
            Modifier
                .fillMaxWidth()
                .height(height * scale),
        shape = RoundedCornerShape(50),
        colors =
            ButtonDefaults.buttonColors(
                backgroundColor = WearPalette.Text,
                contentColor = WearPalette.Background,
                disabledBackgroundColor = WearPalette.Text.copy(alpha = 0.5f),
                disabledContentColor = WearPalette.Background.copy(alpha = 0.6f),
            ),
    ) {
        AutoResizingText(
            text = label,
            fontSize = 20.sp * scale,
            fontWeight = FontWeight.Bold,
            fontFamily = WearDisplayFontFamily,
            textAlign = TextAlign.Center,
            maxLines = 1,
            modifier = Modifier.padding(horizontal = 12.dp),
        )
    }
}

/** A rung's three finishes in one row: white pills like the primary, each a Done. */
@Composable
private fun FinishRow(
    finishes: List<Wearable.WearAction>,
    actionsEnabled: Boolean,
    onAction: (Wearable.WearAction) -> Unit,
    scale: Float,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        finishes.forEach { action ->
            Box(
                modifier =
                    Modifier
                        .weight(1f)
                        .height(44.dp * scale)
                        .clip(RoundedCornerShape(50))
                        .background(WearPalette.Text.copy(alpha = if (actionsEnabled) 1f else 0.5f))
                        .clickable(enabled = actionsEnabled, onClick = { onAction(action) }),
                contentAlignment = Alignment.Center,
            ) {
                AutoResizingText(
                    text = action.label,
                    color = WearPalette.Background,
                    fontSize = 15.sp * scale,
                    fontWeight = FontWeight.Bold,
                    fontFamily = WearDisplayFontFamily,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    minFontSize = 9.sp,
                    modifier = Modifier.padding(horizontal = 2.dp),
                )
            }
        }
    }
}

// ── Text the watch assembles: timers from timestamps, and the summary line
// joined from phone-rendered parts. It never formats a weight. ──

/** "48:12 · 14 sets · 5,650 kg"; the lb figure only if the phone sent no volume text. */
private fun formatSummaryLine(summary: Wearable.WearCompletionSummary): String {
    val volume = summary.volumeText.ifEmpty { "${summary.totalVolumeLb}lb" }
    return "${summary.durationText} · ${summary.completedWorkingSets} sets · $volume"
}

/** Elapsed since the workout started, against the phone-synchronised clock. */
internal fun deriveElapsedText(snapshot: Wearable.WearWorkoutSnapshot): String {
    val startTime = snapshot.workoutStartTime.toLong()
    if (startTime <= 0L) return snapshot.elapsedText
    val currentApiNowMs = WearDataRepository.synchronizedNowUnixMillis()
    val elapsed = ((currentApiNowMs - (startTime * 1000L)).coerceAtLeast(0L) / 1000L).toInt()
    return formatElapsedDuration(elapsed)
}

/** The rest timer: [countingUp] once rest has ended (yapping). */
internal data class RestTimer(
    val text: String,
    val countingUp: Boolean,
)

/** Counts up from Start while a set is being lifted. Decided locally each tick. */
internal fun deriveLiftingTimer(snapshot: Wearable.WearWorkoutSnapshot): String {
    val startedAt = snapshot.liftingStartedAt.toLong()
    if (startedAt <= 0L) return snapshot.youCard.timerText
    val deltaMs = WearDataRepository.synchronizedNowUnixMillis() - startedAt * 1000L
    return formatElapsedDuration((deltaMs.coerceAtLeast(0L) / 1000L).toInt())
}

/**
 * Counts down to restUntil, then up from it until the next Start. Before the
 * first rest of a workout there is no timer. Decided locally each tick, so
 * the watch flips to yapping the second the countdown reaches zero.
 */
internal fun deriveRestTimer(snapshot: Wearable.WearWorkoutSnapshot): RestTimer {
    val restUntil = snapshot.restUntil.toLong()
    if (restUntil <= 0L) return RestTimer(text = snapshot.youCard.timerText, countingUp = false)
    val deltaMs = WearDataRepository.synchronizedNowUnixMillis() - restUntil * 1000L
    return if (deltaMs < 0L) {
        // Round up so the countdown reads 0:01 until it is truly over.
        RestTimer(text = formatDuration(((-deltaMs + 999L) / 1000L).toInt()), countingUp = false)
    } else {
        RestTimer(text = formatElapsedDuration((deltaMs / 1000L).toInt()), countingUp = true)
    }
}

private fun formatDuration(totalSeconds: Int): String {
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%d:%02d".format(minutes, seconds)
}

private fun formatElapsedDuration(totalSeconds: Int): String {
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) {
        "%d:%02d:%02d".format(hours, minutes, seconds)
    } else {
        "%d:%02d".format(minutes, seconds)
    }
}

private fun heartRateColor(bpm: Float?): Color {
    if (bpm == null || bpm <= 0f) return Color(0xFF94A3B8)
    return when {
        bpm < 110f -> Color(0xFF22C55E)
        bpm < 140f -> Color(0xFFFACC15)
        bpm < 165f -> Color(0xFFF97316)
        else -> Color(0xFFEF4444)
    }
}
