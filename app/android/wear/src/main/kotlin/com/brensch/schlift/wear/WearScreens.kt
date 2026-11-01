package com.brensch.schlift.wear

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
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
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.dialog.Dialog
import workout.v1.Wearable
import kotlin.math.abs
import kotlin.math.sqrt

// The watch face, one layout for every state: the phone's status box stacked
// for the wrist, panels split by thin lines. Colours and fonts are the phone app's
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

    // Done short of the target (the phone's effort colour).
    val Effort = Color(0xFFD99A00)
    val FirstTime = Color(0xFF111111)
    val Ambient = Color.Black
    val AmbientText = Color(0xFFB7B6AC)
    val AmbientLine = Color(0xFF4A4A44)

    // The app's series palette: the up-next chip glides through it.
    val Series =
        listOf(
            Color(0xFF1F4FD1),
            Color(0xFFD03A00),
            Color(0xFF1E7A3C),
            Color(0xFFC2185B),
            Color(0xFF5B2DB8),
            Color(0xFF00796B),
            Color(0xFF8D5A00),
        )
}

/** Everything the face prints: the phone's status box, stacked for the wrist. */
internal data class WearFace(
    // The exercise in hand's sets, as the phone's circles; a tap on one taps it.
    val circles: List<Wearable.WearSetCircle>,
    val label: String,
    // The phone's "up next" chip, when you lift next in a session; else empty.
    val upNext: String,
    // Empty: no timer (ready, or a first time).
    val timer: String,
    // The band is [stageColor] over [trackColor], filled to [bandFill]: rest
    // drains it.
    val stageColor: Color,
    val trackColor: Color,
    val bandInk: Color,
    val bandFill: Float,
    val exercise: String,
    val position: String,
    val weight: String,
    val unit: String,
    val reps: String,
    // How the rep circle looks: the set it stands for, as its circle does.
    val repState: Wearable.WearCircleState,
    val bpm: Float?,
    val elapsed: String,
    val clock: String,
    val hasPlates: Boolean,
)

// The done screen's left column, as a fraction of the face.
private const val LEFT_FRACTION = 0.57f

// The face's rows, top to bottom, as fractions of the face.
private const val TOP_ROW = 0.10f
private const val SQUARE_TOP_ROW = 0.03f
private const val CIRCLES_ROW = 0.18f
private const val BAND_ROW = 0.18f
private const val LINE_ROW = 0.10f
private const val WEIGHT_ROW = 0.225f
private const val STATS_ROW = 0.11f

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

/**
 * Shrinks until it fits on one line. The size is worked out again only when
 * the text's length changes, so a ticking clock keeps its size and never
 * blanks for a frame while it measures.
 */
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
    var current by remember(text.length, size) { mutableStateOf(size) }
    var ready by remember(text.length, size) { mutableStateOf(false) }
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
 * The face: the set circles, the band (who, the stage, its clock), the
 * exercise, the weight × reps, then heart rate | workout length | time. A tap
 * on a circle runs [onTapSet] with its set; on the rep circle, [onRep]; on the
 * weight, with plates to show, [onWeight]. Rows sit from the top down, each
 * kept inside a round face's chord.
 */
@Composable
internal fun FaceScreen(
    face: WearFace,
    colors: FaceColors,
    enabled: Boolean,
    onTapSet: (String) -> Unit,
    onRep: () -> Unit,
    onWeight: () -> Unit,
) {
    CompositionLocalProvider(LocalFaceColors provides colors) {
        Face(face, enabled, onTapSet, onRep, onWeight)
    }
}

@Composable
private fun Face(
    face: WearFace,
    enabled: Boolean,
    onTapSet: (String) -> Unit,
    onRep: () -> Unit,
    onWeight: () -> Unit,
) {
    val c = LocalFaceColors.current
    val round = LocalConfiguration.current.isScreenRound
    BoxWithConstraints(
        modifier =
            Modifier
                .fillMaxSize()
                .background(c.ground),
    ) {
        val d = minOf(maxWidth, maxHeight)
        val top = if (round) TOP_ROW else SQUARE_TOP_ROW
        val bandTop = top + CIRCLES_ROW
        val lineTop = bandTop + BAND_ROW
        val weightTop = lineTop + LINE_ROW
        val statsTop = weightTop + WEIGHT_ROW
        // Text rows keep at least the phone box's side margin.
        val side = d * 0.067f
        Column(modifier = Modifier.fillMaxSize()) {
            Spacer(modifier = Modifier.height(d * top))
            SetRow(
                face = face,
                d = d,
                inset = roundInset(d, round, top + 0.03f, top + CIRCLES_ROW - 0.03f),
                enabled = enabled,
                onTapSet = onTapSet,
            )
            Rule(c.hairline)
            Band(face = face, d = d, inset = roundInset(d, round, bandTop, bandTop + BAND_ROW))
            Rule(c.hairline)
            Box(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .height(d * LINE_ROW)
                        .background(c.panel)
                        .padding(horizontal = maxOf(roundInset(d, round, lineTop, lineTop + LINE_ROW), side)),
                contentAlignment = Alignment.CenterStart,
            ) {
                FitText(
                    text = listOf(face.exercise, face.position).filter { it.isNotEmpty() }.joinToString(" · "),
                    size = (d * 0.047f).asSp(),
                    color = c.muted,
                    weight = FontWeight.Medium,
                    family = WearBodyFontFamily,
                    align = TextAlign.Start,
                )
            }
            Rule(c.hairline)
            WeightRow(
                face = face,
                d = d,
                inset = maxOf(roundInset(d, round, weightTop, weightTop + WEIGHT_ROW), side),
                enabled = enabled,
                onRep = onRep,
                onWeight = onWeight,
            )
            Rule(c.hairline)
            Stats(face = face, d = d, inset = roundInset(d, round, statsTop + 0.02f, statsTop + STATS_ROW - 0.02f))
            Rule(c.hairline)
        }
    }
}

/**
 * The face's colours: the app's, or dimmed for always-on, where the same face
 * is drawn as grey lines and text on black.
 */
internal data class FaceColors(
    val ground: Color,
    val panel: Color,
    val hairline: Color,
    val rule: Color,
    val text: Color,
    val muted: Color,
    val dim: Boolean,
)

internal val LitColors =
    FaceColors(
        ground = WearPalette.Ground,
        panel = WearPalette.Panel,
        hairline = WearPalette.Hairline,
        rule = WearPalette.Rule,
        text = WearPalette.Text,
        muted = WearPalette.Muted,
        dim = false,
    )

internal val DimColors =
    FaceColors(
        ground = WearPalette.Ambient,
        panel = WearPalette.Ambient,
        hairline = WearPalette.AmbientLine,
        rule = WearPalette.AmbientLine,
        text = WearPalette.AmbientText,
        muted = WearPalette.AmbientText,
        dim = true,
    )

private val LocalFaceColors = staticCompositionLocalOf { LitColors }

/** How a set circle is drawn: the phone's SetCircle colours. */
private data class CircleLook(
    val fill: Color,
    val ring: Color,
    val ink: Color,
)

private fun circleLook(
    state: Wearable.WearCircleState,
    stage: Color,
    c: FaceColors,
): CircleLook =
    if (c.dim) {
        // Dimmed, every circle is an outline: no lit discs.
        CircleLook(Color.Transparent, c.rule, c.text)
    } else {
        when (state) {
            Wearable.WearCircleState.WEAR_CIRCLE_STATE_NEXT -> CircleLook(Color.Transparent, stage, stage)
            Wearable.WearCircleState.WEAR_CIRCLE_STATE_LIFTING -> CircleLook(WearPalette.Lifting, WearPalette.Lifting, c.text)
            Wearable.WearCircleState.WEAR_CIRCLE_STATE_FULL -> CircleLook(c.text, c.text, c.ground)
            Wearable.WearCircleState.WEAR_CIRCLE_STATE_SHORT -> CircleLook(WearPalette.Effort, WearPalette.Effort, c.text)
            Wearable.WearCircleState.WEAR_CIRCLE_STATE_ZERO -> CircleLook(Color.Transparent, WearPalette.Effort, WearPalette.Effort)
            Wearable.WearCircleState.WEAR_CIRCLE_STATE_SKIPPED -> CircleLook(Color.Transparent, c.hairline, c.muted)
            else -> CircleLook(Color.Transparent, c.rule, c.muted)
        }
    }

/** The exercise's sets, every one tappable, scrolled to the one in hand. */
@Composable
private fun SetRow(
    face: WearFace,
    d: Dp,
    inset: Dp,
    enabled: Boolean,
    onTapSet: (String) -> Unit,
) {
    val c = LocalFaceColors.current
    val list = rememberLazyListState()
    val current =
        face.circles.indexOfFirst {
            it.state == Wearable.WearCircleState.WEAR_CIRCLE_STATE_LIFTING ||
                it.state == Wearable.WearCircleState.WEAR_CIRCLE_STATE_NEXT
        }
    LaunchedEffect(current, face.circles.size) {
        // One done set stays in view to the left of the one in hand.
        if (current > 0) list.animateScrollToItem(current - 1)
    }
    LazyRow(
        state = list,
        modifier =
            Modifier
                .fillMaxWidth()
                .height(d * CIRCLES_ROW),
        contentPadding = PaddingValues(horizontal = inset),
        horizontalArrangement = Arrangement.spacedBy(d * 0.02f, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        items(face.circles, key = { it.setId }) { circle ->
            val size = if (circle.warmup) d * 0.10f else d * 0.12f
            val look = circleLook(circle.state, face.stageColor, c)
            Box(
                modifier =
                    Modifier
                        .size(size)
                        .clip(CircleShape)
                        .background(look.fill)
                        .border(
                            width = if (circle.state == Wearable.WearCircleState.WEAR_CIRCLE_STATE_NEXT) 2.5.dp else 1.5.dp,
                            color = look.ring,
                            shape = CircleShape,
                        ).clickable(enabled = enabled) { onTapSet(circle.setId) },
                contentAlignment = Alignment.Center,
            ) {
                FitText(text = circle.text, size = (size * 0.45f).asSp(), color = look.ink, align = TextAlign.Center)
            }
        }
    }
}

/**
 * The phone's status band: the stage, up next when it's you, its clock.
 * While resting the stage colour drains off it.
 */
@Composable
private fun Band(
    face: WearFace,
    d: Dp,
    inset: Dp,
) {
    val c = LocalFaceColors.current
    Box(
        modifier =
            Modifier
                .fillMaxWidth()
                .height(d * BAND_ROW)
                .background(face.trackColor),
    ) {
        Box(
            modifier =
                Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(face.bandFill.coerceIn(0f, 1f))
                    .background(face.stageColor),
        )
        Row(modifier = Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            FitText(
                text = face.label.uppercase(),
                size = (d * 0.064f).asSp(),
                color = face.bandInk,
                align = TextAlign.Start,
                modifier = Modifier.weight(1f).padding(start = inset + d * 0.02f),
            )
            if (face.upNext.isNotEmpty()) UpNextChip(text = face.upNext, d = d)
            if (face.timer.isNotEmpty()) {
                FitText(
                    text = face.timer,
                    size = (d * 0.107f).asSp(),
                    color = face.bandInk,
                    modifier = Modifier.padding(start = 4.dp, end = inset),
                )
            }
        }
    }
}

/** "Up next!" on the panel, its ink gliding through the series palette. */
@Composable
private fun UpNextChip(
    text: String,
    d: Dp,
) {
    val c = LocalFaceColors.current
    val colors = WearPalette.Series
    val cycle by rememberInfiniteTransition(label = "upNext").animateFloat(
        initialValue = 0f,
        targetValue = colors.size.toFloat(),
        animationSpec = infiniteRepeatable(tween(durationMillis = colors.size * 700, easing = LinearEasing)),
        label = "upNextCycle",
    )
    val at = cycle.toInt()
    // Dimmed, nothing moves: the chip keeps the face's grey.
    val color = if (c.dim) c.text else lerp(colors[at % colors.size], colors[(at + 1) % colors.size], cycle - at)
    Text(
        text = text,
        color = color,
        fontSize = (d * 0.036f).asSp(),
        lineHeight = (d * 0.04f).asSp(),
        fontWeight = FontWeight.Bold,
        fontFamily = WearMonoFontFamily,
        textAlign = TextAlign.Center,
        maxLines = 2,
        modifier =
            Modifier
                .padding(start = 4.dp)
                .background(c.panel)
                .padding(horizontal = 4.dp, vertical = 2.dp),
    )
}

/** The weight (tap it for the plates) × the reps, in the set's circle. */
@Composable
private fun WeightRow(
    face: WearFace,
    d: Dp,
    inset: Dp,
    enabled: Boolean,
    onRep: () -> Unit,
    onWeight: () -> Unit,
) {
    val c = LocalFaceColors.current
    // The weight's touch lights the panel orange from the face's edge to the ×.
    val press = remember { MutableInteractionSource() }
    val pressed by press.collectIsPressedAsState()
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .height(d * WEIGHT_ROW)
                .background(c.panel)
                .padding(end = inset),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier =
                Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .background(if (pressed) WearPalette.Lifting else Color.Transparent)
                    .clickable(
                        interactionSource = press,
                        indication = null,
                        enabled = face.hasPlates,
                        onClick = onWeight,
                    ).padding(start = inset),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            FitText(
                text = face.weight,
                size = (d * 0.147f).asSp(),
                color = c.text,
                align = TextAlign.Start,
                modifier = Modifier.weight(1f, fill = false).alignByBaseline(),
            )
            if (face.weight != "?" && face.unit.isNotEmpty()) {
                Text(
                    text = " ${face.unit}",
                    color = c.text,
                    fontSize = (d * 0.05f).asSp(),
                    fontWeight = FontWeight.Bold,
                    fontFamily = WearMonoFontFamily,
                    maxLines = 1,
                    modifier = Modifier.alignByBaseline(),
                )
            }
        }
        Text(
            text = "×",
            color = c.text,
            fontSize = (d * 0.067f).asSp(),
            fontWeight = FontWeight.Bold,
            fontFamily = WearMonoFontFamily,
            modifier = Modifier.padding(horizontal = d * 0.02f),
        )
        val look = circleLook(face.repState, face.stageColor, c)
        val outer = d * 0.187f
        Box(
            modifier =
                Modifier
                    .size(outer)
                    .clip(CircleShape)
                    .background(look.ring)
                    .clickable(enabled = enabled, onClick = onRep),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier =
                    Modifier
                        .size(outer * 0.86f)
                        .clip(CircleShape)
                        .background(if (look.fill == Color.Transparent) c.panel else look.fill),
                contentAlignment = Alignment.Center,
            ) {
                FitText(text = face.reps, size = (d * 0.087f).asSp(), color = look.ink, align = TextAlign.Center)
            }
        }
    }
}

/** Heart rate | workout length | the time. */
@Composable
private fun Stats(
    face: WearFace,
    d: Dp,
    inset: Dp,
) {
    val c = LocalFaceColors.current
    val size = (d * 0.047f).asSp()

    @Composable
    fun Divider() {
        Box(
            modifier =
                Modifier
                    .width(1.dp)
                    .fillMaxHeight()
                    .background(c.hairline),
        )
    }
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .height(d * STATS_ROW)
                .padding(horizontal = inset),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // A drawn heart: a "♥" character falls back to the emoji font.
        Row(
            modifier = Modifier.weight(1f),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Filled.Favorite,
                contentDescription = null,
                tint = if (c.dim) c.muted else heartRateColor(face.bpm),
                modifier = Modifier.size(d * 0.042f),
            )
            FitText(text = face.bpm?.let { "${it.toInt()}" } ?: "--", size = size, color = if (c.dim) c.muted else heartRateColor(face.bpm))
        }
        Divider()
        FitText(text = face.elapsed, size = size, color = c.muted, align = TextAlign.Center, modifier = Modifier.weight(1f))
        Divider()
        FitText(text = face.clock, size = size, color = c.muted, align = TextAlign.Center, modifier = Modifier.weight(1f))
    }
}

/**
 * The plates for the set's weight, as a Wear dialog over the face: the bar
 * drawn loaded on white, the plates each side, the bar's own weight. Swipe it
 * away or tap the close button.
 */
@Composable
internal fun PlateDialog(
    card: Wearable.WearStatusCard,
    show: Boolean,
    onDismiss: () -> Unit,
) {
    Dialog(showDialog = show, onDismissRequest = onDismiss) {
        BoxWithConstraints(
            modifier =
                Modifier
                    .fillMaxSize()
                    .background(WearPalette.Panel),
        ) {
            val d = minOf(maxWidth, maxHeight)
            Column(
                modifier = Modifier.fillMaxSize().padding(top = d * 0.12f, bottom = d * 0.06f),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                FitText(text = "${card.weightText} ${card.unitText}", size = (d * 0.13f).asSp(), align = TextAlign.Center)
                Spacer(modifier = Modifier.height(4.dp))
                Rule()
                Box(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .height(d * 0.28f)
                            .background(Color.White),
                    contentAlignment = Alignment.Center,
                ) {
                    Bar(plates = card.platesList, height = d * 0.24f)
                }
                Rule()
                Spacer(modifier = Modifier.height(4.dp))
                FitText(
                    text = card.platesText,
                    size = (d * 0.065f).asSp(),
                    align = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = d * 0.14f),
                )
                FitText(text = card.barText, size = (d * 0.055f).asSp(), color = WearPalette.Muted, align = TextAlign.Center)
                Spacer(modifier = Modifier.weight(1f))
                Button(
                    onClick = onDismiss,
                    modifier = Modifier.size(d * 0.17f),
                    colors =
                        ButtonDefaults.buttonColors(
                            backgroundColor = WearPalette.Text,
                            contentColor = WearPalette.Panel,
                        ),
                ) {
                    Icon(
                        imageVector = Icons.Filled.Close,
                        contentDescription = "Close",
                        modifier = Modifier.size(d * 0.08f),
                    )
                }
            }
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

/**
 * Rest on the dimmed face, in whole minutes: it is redrawn about once a
 * minute, so seconds would be wrong most of the time. [until] is when rest
 * ends, which stays right however late the redraw comes.
 */
internal data class AmbientRest(
    val minutes: String,
    val until: String,
)

internal fun ambientRest(snapshot: Wearable.WearWorkoutSnapshot): AmbientRest? {
    val restUntilMs = snapshot.restUntil.toLong() * 1000L
    if (restUntilMs <= 0L) return null
    val words = snapshot.ambientCopy
    val nowMs = WearDataRepository.synchronizedNowUnixMillis()
    val leftMs = restUntilMs - nowMs
    val minutes =
        when {
            leftMs > MINUTE_MS -> words.minLeft.replace("{n}", "${(leftMs + MINUTE_MS - 1) / MINUTE_MS}")
            leftMs > 0L -> words.underAMin
            else -> words.minOver.replace("{n}", "${maxOf(1L, (-leftMs + MINUTE_MS - 1) / MINUTE_MS)}")
        }
    // restUntil is the phone's clock; the end as this watch's clock reads it.
    val endsAt = restUntilMs - (nowMs - System.currentTimeMillis())
    val time =
        java.text
            .SimpleDateFormat("H:mm", java.util.Locale.getDefault())
            .format(java.util.Date(endsAt))
    // Once rest is over its end is past: no "till".
    val until = if (leftMs > 0L) words.restUntil.replace("{time}", time) else ""
    return AmbientRest(minutes = minutes, until = until)
}

/**
 * How long the dimmed face waits before redrawing: to the next whole minute
 * of rest (so the count turns over on time) or of the clock, whichever is
 * first.
 */
internal fun ambientDelayMs(snapshot: Wearable.WearWorkoutSnapshot?): Long {
    val restUntilMs = (snapshot?.restUntil ?: 0).toLong() * 1000L
    val nowMs = WearDataRepository.synchronizedNowUnixMillis()
    // The clock on the face turns over on the minute too: whichever is first.
    val clock = MINUTE_MS - Math.floorMod(System.currentTimeMillis(), MINUTE_MS)
    val phase =
        if (restUntilMs > 0L) {
            minOf(Math.floorMod(restUntilMs - nowMs, MINUTE_MS), clock)
        } else {
            clock
        }
    // A moment past the turn, so the count has already changed.
    return phase + AMBIENT_SLACK_MS
}

private const val MINUTE_MS = 60_000L
private const val AMBIENT_SLACK_MS = 300L

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

internal fun parseHex(hex: String): Color = runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(WearPalette.Muted)
