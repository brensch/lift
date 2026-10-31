package com.brensch.schlift.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import workout.v1.Wearable
import kotlin.math.abs
import kotlin.math.sqrt

// The watch face, one layout for every state (the "split"): information rows
// on the left, split by thin lines; the right is one big button in the
// state's colour with the reps on it. Colours and fonts are the phone app's
// (app/lib/theme/schlift_spec.dart). The watch lays out strings the phone
// rendered; it never derives text from the workout.

internal val WearBodyFontFamily =
    FontFamily(
        Font(R.font.space_grotesk_variable, weight = FontWeight.Medium),
        Font(R.font.space_grotesk_variable, weight = FontWeight.Bold),
    )

internal val WearMonoFontFamily =
    FontFamily(
        Font(R.font.space_mono_regular, weight = FontWeight.Normal),
        Font(R.font.space_mono_bold, weight = FontWeight.Bold),
    )

/** The phone app's tokens. */
internal object WearPalette {
    val Ground = Color(0xFFDBDAD2)
    val Panel = Color(0xFFEDECE5)
    val Hairline = Color(0xFFA8A79F)
    val Rule = Color(0xFF74746E)
    val Text = Color(0xFF111111)
    val Muted = Color(0xFF4A4A44)
    val OnDark = Color(0xFFFFFFFF)
    val Ready = Color(0xFF3D8B4A)
    val ReadyInk = Color(0xFF2F6E3A)
    val Lifting = Color(0xFFFF4F00)
    val LiftingInk = Color(0xFFC23C00)
    val Resting = Color(0xFF3C5FB0)
    val Yapping = Color(0xFFD94F8C)
    val YappingInk = Color(0xFFB0306B)
    val Fix = Color(0xFFD99A00)
    val FirstTime = Color(0xFF111111)
    val Ambient = Color.Black
    val AmbientText = Color(0xFFB7B6AC)
}

/** Everything the split face prints. */
internal data class SplitFace(
    val label: String,
    val labelColor: Color,
    // Empty: no timer (ready, or ambient).
    val timer: String,
    val bpm: Float?,
    val elapsed: String,
    val clock: String,
    val exercise: String,
    val position: String,
    val weight: String,
    val unit: String,
    // Empty when solo.
    val upNext: String,
    val reps: String,
    val cue: String,
    val buttonColor: Color,
    val buttonInk: Color,
    // 0..1 of the fix window left: the bar down the button's inner edge.
    val window: Float,
    val hasPlates: Boolean,
)

// The left column's share of the face, and its rows' heights, as fractions
// of the face.
private const val LEFT_FRACTION = 0.57f
private const val TOP_PAD = 0.11f
private const val STAGE_ROW = 0.25f
private const val STATS_ROW = 0.11f
private const val EXERCISE_ROW = 0.09f
private const val WEIGHT_ROW = 0.15f

/**
 * How far in from the left a line between [top] and [bottom] (fractions of
 * the face, 0 at the top) must start to stay inside a round face: the chord
 * at whichever edge is nearer the rim. Nothing on a square face.
 */
private fun roundInset(
    face: Dp,
    round: Boolean,
    top: Float,
    bottom: Float,
): Dp {
    if (!round) return 6.dp
    val off = maxOf(abs(top - 0.5f), abs(bottom - 0.5f)).coerceAtMost(0.5f)
    val chord = sqrt(1f - (2f * off) * (2f * off))
    return face * (0.5f * (1f - chord)) + 6.dp
}

@Composable
private fun Dp.asSp(): TextUnit = with(LocalDensity.current) { this@asSp.toSp() }

/** Shrinks until it fits on one line. */
@Composable
internal fun FitText(
    text: String,
    size: TextUnit,
    modifier: Modifier = Modifier,
    color: Color = WearPalette.Text,
    weight: FontWeight = FontWeight.Bold,
    family: FontFamily = WearMonoFontFamily,
    align: TextAlign = TextAlign.End,
) {
    var current by remember(text, size) { mutableStateOf(size) }
    var ready by remember(text, size) { mutableStateOf(false) }
    Text(
        text = text,
        modifier = modifier.drawWithContent { if (ready) drawContent() },
        color = color,
        fontSize = current,
        fontWeight = weight,
        fontFamily = family,
        textAlign = align,
        maxLines = 1,
        softWrap = false,
        overflow = TextOverflow.Clip,
        onTextLayout = { layout ->
            if (layout.hasVisualOverflow && current.value > 7f) {
                current = (current.value * 0.9f).sp
            } else {
                ready = true
            }
        },
    )
}

/** A full-width line. */
@Composable
private fun Rule(color: Color = WearPalette.Hairline) {
    Box(
        modifier =
            Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(color),
    )
}

/**
 * The split face. A tap on the right half runs [onTap]; on the weight, with
 * plates to show, [onWeight].
 */
@Composable
internal fun SplitScreen(
    face: SplitFace,
    enabled: Boolean,
    onTap: () -> Unit,
    onWeight: () -> Unit,
) {
    val round = LocalConfiguration.current.isScreenRound
    BoxWithConstraints(
        modifier =
            Modifier
                .fillMaxSize()
                .background(WearPalette.Ground),
    ) {
        val d = minOf(maxWidth, maxHeight)

        // One right-aligned line between [top] and [bottom] of the face.
        @Composable
        fun Line(
            top: Float,
            bottom: Float,
            content: @Composable (Modifier) -> Unit,
        ) {
            content(
                Modifier
                    .fillMaxWidth()
                    .padding(start = roundInset(d, round, top, bottom), end = 8.dp),
            )
        }

        Row(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier =
                    Modifier
                        .width(d * LEFT_FRACTION)
                        .fillMaxHeight(),
            ) {
                Spacer(modifier = Modifier.height(d * TOP_PAD))
                // The stage and its clock.
                val stageTop = TOP_PAD
                Column(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .height(d * STAGE_ROW),
                    verticalArrangement = Arrangement.Bottom,
                ) {
                    Line(stageTop, stageTop + 0.07f) { m ->
                        FitText(text = face.label.uppercase(), size = (d * 0.062f).asSp(), color = face.labelColor, modifier = m)
                    }
                    if (face.timer.isNotEmpty()) {
                        Line(stageTop + 0.07f, stageTop + STAGE_ROW) { m ->
                            FitText(text = face.timer, size = (d * 0.17f).asSp(), modifier = m)
                        }
                    }
                }
                Rule()
                // Heart rate | workout length.
                val statsTop = TOP_PAD + STAGE_ROW
                Row(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .height(d * STATS_ROW)
                            .background(WearPalette.Panel)
                            .padding(start = roundInset(d, round, statsTop, statsTop + STATS_ROW)),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // A drawn heart: a "♥" character falls back to the emoji font.
                    Row(
                        modifier = Modifier.weight(1f).padding(end = 6.dp),
                        horizontalArrangement = Arrangement.End,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Favorite,
                            contentDescription = null,
                            tint = heartRateColor(face.bpm),
                            modifier = Modifier.size(d * 0.06f),
                        )
                        FitText(
                            text = face.bpm?.let { "${it.toInt()}" } ?: "--",
                            size = (d * 0.075f).asSp(),
                            color = heartRateColor(face.bpm),
                        )
                    }
                    Box(
                        modifier =
                            Modifier
                                .width(1.dp)
                                .fillMaxHeight()
                                .background(WearPalette.Hairline),
                    )
                    FitText(
                        text = face.elapsed,
                        size = (d * 0.075f).asSp(),
                        modifier = Modifier.weight(1f).padding(end = 8.dp),
                    )
                }
                Rule()
                // Exercise and where in it.
                val exerciseTop = statsTop + STATS_ROW
                Box(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .height(d * EXERCISE_ROW)
                            .background(WearPalette.Panel),
                    contentAlignment = Alignment.CenterEnd,
                ) {
                    Line(exerciseTop, exerciseTop + EXERCISE_ROW) { m ->
                        FitText(
                            text = listOf(face.exercise, face.position).filter { it.isNotEmpty() }.joinToString(" "),
                            size = (d * 0.066f).asSp(),
                            family = WearBodyFontFamily,
                            modifier = m,
                        )
                    }
                }
                Rule()
                // The weight; tap it for the plates.
                val weightTop = exerciseTop + EXERCISE_ROW
                Box(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .height(d * WEIGHT_ROW)
                            .background(WearPalette.Panel)
                            .clickable(enabled = face.hasPlates, onClick = onWeight),
                    contentAlignment = Alignment.CenterEnd,
                ) {
                    Line(weightTop, weightTop + WEIGHT_ROW) { m ->
                        FitText(
                            text = if (face.weight == "?") "?" else "${face.weight} ${face.unit}",
                            size = (d * 0.15f).asSp(),
                            modifier = m,
                        )
                    }
                }
                Rule()
                // The time, and who's up next.
                val clockTop = weightTop + WEIGHT_ROW
                Column(modifier = Modifier.fillMaxWidth().padding(top = 3.dp)) {
                    Line(clockTop, clockTop + 0.075f) { m ->
                        FitText(text = face.clock, size = (d * 0.062f).asSp(), color = WearPalette.Muted, modifier = m)
                    }
                    if (face.upNext.isNotEmpty()) {
                        Line(clockTop + 0.075f, clockTop + 0.15f) { m ->
                            FitText(text = face.upNext, size = (d * 0.058f).asSp(), color = WearPalette.Muted, modifier = m)
                        }
                    }
                }
            }
            Box(
                modifier =
                    Modifier
                        .width(1.dp)
                        .fillMaxHeight()
                        .background(WearPalette.Rule),
            )
            BigButton(face = face, faceSize = d, enabled = enabled, onTap = onTap)
        }
    }
}

/** The right half: the reps, huge, and what a tap does. */
@Composable
private fun RowScope.BigButton(
    face: SplitFace,
    faceSize: Dp,
    enabled: Boolean,
    onTap: () -> Unit,
) {
    Row(
        modifier =
            Modifier
                .weight(1f)
                .fillMaxHeight()
                .background(face.buttonColor)
                .clickable(enabled = enabled, onClick = onTap),
    ) {
        // The fix window drains down the inner edge.
        Box(
            modifier =
                Modifier
                    .width(8.dp)
                    .fillMaxHeight()
                    .background(if (face.window > 0f) WearPalette.Rule else face.buttonColor),
            contentAlignment = Alignment.BottomCenter,
        ) {
            if (face.window > 0f) {
                Box(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .fillMaxHeight(face.window.coerceIn(0f, 1f))
                            .background(face.buttonInk),
                )
            }
        }
        Column(
            modifier =
                Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .padding(end = faceSize * 0.07f),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            FitText(text = face.reps, size = (faceSize * 0.32f).asSp(), color = face.buttonInk, align = TextAlign.Center)
            FitText(text = face.cue.uppercase(), size = (faceSize * 0.06f).asSp(), color = face.buttonInk, align = TextAlign.Center)
        }
    }
}

/** The bar loaded, the plates each side, the bar's own weight. Tap to close. */
@Composable
internal fun PlateScreen(
    card: Wearable.WearStatusCard,
    onClose: () -> Unit,
) {
    BoxWithConstraints(
        modifier =
            Modifier
                .fillMaxSize()
                .background(WearPalette.Ground)
                .clickable(onClick = onClose),
    ) {
        val d = minOf(maxWidth, maxHeight)
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            FitText(text = "${card.weightText} ${card.unitText}", size = (d * 0.14f).asSp(), align = TextAlign.Center)
            Spacer(modifier = Modifier.height(6.dp))
            Rule()
            Box(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .height(d * 0.30f)
                        .background(Color.White),
                contentAlignment = Alignment.Center,
            ) {
                Bar(plates = card.platesList, height = d * 0.26f)
            }
            Rule()
            Spacer(modifier = Modifier.height(6.dp))
            FitText(
                text = card.platesText,
                size = (d * 0.07f).asSp(),
                align = TextAlign.Center,
                modifier = Modifier.padding(horizontal = d * 0.12f),
            )
            FitText(text = card.barText, size = (d * 0.06f).asSp(), color = WearPalette.Muted, align = TextAlign.Center)
        }
    }
}

/** A barbell drawn loaded: plates out from the collars, sized by weight. */
@Composable
private fun Bar(
    plates: List<Wearable.WearPlate>,
    height: Dp,
) {
    @Composable
    fun Plate(plate: Wearable.WearPlate) {
        Box(
            modifier =
                Modifier
                    .padding(horizontal = 1.dp)
                    .width(4.dp + 7.dp * plate.size)
                    .height(height * (0.32f + 0.68f * plate.size))
                    .background(parseHex(plate.colorHex)),
        )
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(modifier = Modifier.width(12.dp).height(4.dp).background(WearPalette.Hairline))
        plates.reversed().forEach { Plate(it) }
        Box(modifier = Modifier.width(5.dp).height(12.dp).background(WearPalette.Rule))
        Box(modifier = Modifier.width(36.dp).height(3.dp).background(WearPalette.Muted))
        Box(modifier = Modifier.width(5.dp).height(12.dp).background(WearPalette.Rule))
        plates.forEach { Plate(it) }
        Box(modifier = Modifier.width(12.dp).height(4.dp).background(WearPalette.Hairline))
    }
}

/** Ambient: the face dimmed to what matters, grey on black. */
@Composable
internal fun AmbientScreen(face: SplitFace) {
    BoxWithConstraints(
        modifier =
            Modifier
                .fillMaxSize()
                .background(WearPalette.Ambient),
        contentAlignment = Alignment.Center,
    ) {
        val d = minOf(maxWidth, maxHeight)
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            FitText(text = face.label.uppercase(), size = (d * 0.07f).asSp(), color = WearPalette.AmbientText, align = TextAlign.Center)
            FitText(
                text = listOf(face.exercise, face.position).filter { it.isNotEmpty() }.joinToString(" "),
                size = (d * 0.07f).asSp(),
                color = WearPalette.AmbientText,
                family = WearBodyFontFamily,
                align = TextAlign.Center,
            )
            FitText(
                text = if (face.weight == "?") "?" else "${face.weight} × ${face.reps}",
                size = (d * 0.13f).asSp(),
                color = WearPalette.AmbientText,
                align = TextAlign.Center,
            )
        }
    }
}

/** ALL_DONE: the summary on the left, End workout as the big half. */
@Composable
internal fun DoneScreen(
    summary: Wearable.WearCompletionSummary?,
    label: String,
    endWorkout: Wearable.WearAction?,
    enabled: Boolean,
    onAction: (Wearable.WearAction) -> Unit,
) {
    BoxWithConstraints(
        modifier =
            Modifier
                .fillMaxSize()
                .background(WearPalette.Ground),
    ) {
        val d = minOf(maxWidth, maxHeight)
        val round = LocalConfiguration.current.isScreenRound
        Row(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier =
                    Modifier
                        .width(d * LEFT_FRACTION)
                        .fillMaxHeight()
                        .padding(end = 8.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.End,
            ) {
                DoneLine(d, round, 0.32f, label.uppercase(), 0.07f, WearPalette.ReadyInk)
                if (summary != null) {
                    DoneLine(d, round, 0.40f, summary.durationText, 0.13f, WearPalette.Text)
                    DoneLine(d, round, 0.55f, "${summary.completedWorkingSets} sets", 0.075f, WearPalette.Muted)
                    DoneLine(d, round, 0.64f, summary.volumeText.ifEmpty { "${summary.totalVolumeLb} lb" }, 0.075f, WearPalette.Muted)
                }
            }
            Box(
                modifier =
                    Modifier
                        .width(1.dp)
                        .fillMaxHeight()
                        .background(WearPalette.Rule),
            )
            Box(
                modifier =
                    Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .background(if (endWorkout != null) WearPalette.Ready else WearPalette.Panel)
                        .clickable(enabled = enabled && endWorkout != null) { endWorkout?.let(onAction) }
                        .padding(end = d * 0.07f),
                contentAlignment = Alignment.Center,
            ) {
                if (endWorkout != null) {
                    FitText(
                        text = endWorkout.label.uppercase(),
                        size = (d * 0.07f).asSp(),
                        color = WearPalette.OnDark,
                        align = TextAlign.Center,
                    )
                }
            }
        }
    }
}

@Composable
private fun ColumnScope.DoneLine(
    d: Dp,
    round: Boolean,
    top: Float,
    text: String,
    size: Float,
    color: Color,
) {
    FitText(
        text = text,
        size = (d * size).asSp(),
        color = color,
        modifier = Modifier.fillMaxWidth().padding(start = roundInset(d, round, top, top + size)),
    )
}

/** No snapshot, or the workout is over. */
@Composable
internal fun IdleScreen() {
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(WearPalette.Ground)
                .padding(horizontal = 28.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Open Schlift on your phone",
            color = WearPalette.Muted,
            fontSize = 15.sp,
            fontFamily = WearBodyFontFamily,
            textAlign = TextAlign.Center,
            maxLines = 2,
        )
    }
}

// ── Text the watch assembles: timers from timestamps. It never formats a
// weight. ──

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

/** Heart rate in the app's colours: easy green, working ochre, hard orange, max magenta. */
private fun heartRateColor(bpm: Float?): Color {
    if (bpm == null || bpm <= 0f) return WearPalette.Muted
    return when {
        bpm < 110f -> WearPalette.ReadyInk
        bpm < 140f -> Color(0xFF8D5A00)
        bpm < 165f -> WearPalette.LiftingInk
        else -> Color(0xFFC2185B)
    }
}

private fun parseHex(hex: String): Color = runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(WearPalette.Muted)
