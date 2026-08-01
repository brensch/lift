use crate::program_state::{FieldVal, StatePayload};

pub const STATE_WEIGHT_UNIT_KEY: &str = "__weight_unit";
const LB_TO_KG: f32 = 0.453_592_37;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AppWeightUnit {
    Lb,
    Kg,
}

pub fn weight_unit_from_state(state: &StatePayload) -> AppWeightUnit {
    match state.get(STATE_WEIGHT_UNIT_KEY) {
        Some(FieldVal::Str(unit)) if unit.eq_ignore_ascii_case("kg") => AppWeightUnit::Kg,
        _ => AppWeightUnit::Lb,
    }
}

pub fn pounds_to_kg(lb: f32) -> f32 {
    lb * LB_TO_KG
}

pub fn kg_to_pounds(kg: f32) -> f32 {
    kg / LB_TO_KG
}

pub fn round_to_unit_increment(
    weight_lb: f32,
    unit: AppWeightUnit,
    lb_step: f32,
    kg_step: f32,
) -> f32 {
    match unit {
        AppWeightUnit::Lb => (weight_lb / lb_step).round() * lb_step,
        AppWeightUnit::Kg => kg_to_pounds((pounds_to_kg(weight_lb) / kg_step).round() * kg_step),
    }
}

pub fn min_weight_lb(unit: AppWeightUnit, min_lb: f32, min_kg: f32) -> f32 {
    match unit {
        AppWeightUnit::Lb => min_lb,
        AppWeightUnit::Kg => kg_to_pounds(min_kg),
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic plate math.
//
// Everything below is generic over a bar + plate *profile* expressed in a unit's
// own scale. Adding a third unit tomorrow is a single new arm in `bar_weight`
// and `plates` — no algorithm changes. Weights are stored canonically in pounds;
// callers convert to the display unit (`pounds_to_kg`) before snapping so the
// result is a weight you can actually load in that unit, then convert back.
// ─────────────────────────────────────────────────────────────────────────────

/// The empty-bar weight in the unit's own scale (45 lb / 20 kg).
pub fn bar_weight(unit: AppWeightUnit) -> f32 {
    match unit {
        AppWeightUnit::Lb => 45.0,
        AppWeightUnit::Kg => 20.0,
    }
}

/// Available plate denominations, heaviest first, in the unit's own scale.
/// Must mirror `standardPlates` in app/lib/logic/weight_units.dart.
pub fn plates(unit: AppWeightUnit) -> &'static [f32] {
    match unit {
        AppWeightUnit::Lb => &[45.0, 35.0, 25.0, 10.0, 5.0, 2.5],
        AppWeightUnit::Kg => &[25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25],
    }
}

/// The finest total weight you can add to the bar: two of the smallest plate
/// (one per side). Loadable weights are exactly `bar + step * n`.
pub fn loadable_step(plates: &[f32]) -> f32 {
    plates.last().copied().unwrap_or(2.5) * 2.0
}

/// Greedy heaviest-first plates for ONE side to reach `weight` on `bar`, plus
/// any remainder that can't be plated. Pure; `weight`, `bar`, `plates` share a
/// unit. Mirrors `calcPlatesPerSide` in Dart.
pub fn plates_per_side(weight: f32, bar: f32, plates: &[f32]) -> (Vec<f32>, f32) {
    if weight <= bar {
        return (Vec::new(), 0.0);
    }
    let mut remaining = (weight - bar) / 2.0;
    let mut out = Vec::new();
    for &p in plates {
        while remaining + 1e-4 >= p {
            out.push(p);
            remaining -= p;
        }
    }
    (out, remaining.max(0.0))
}

/// "Simplicity" score for a load: plates per side (fewer = bigger plates = the
/// step-up the user asked for). A weight that can't be loaded exactly scores
/// `INFINITY`, so it's never chosen as simplest.
pub fn plate_count_per_side(weight: f32, bar: f32, plates: &[f32]) -> f32 {
    let (used, remainder) = plates_per_side(weight, bar, plates);
    if remainder > 1e-3 {
        f32::INFINITY
    } else {
        used.len() as f32
    }
}

/// Nearest weight to `target` that is exactly loadable on `bar` from `plates`.
/// Loadable weights are `bar + step * n`; below the bar we fall back to the
/// smallest-plate grid so very light warmups still land on real values.
pub fn snap_loadable(target: f32, bar: f32, plates: &[f32]) -> f32 {
    let step = loadable_step(plates);
    if target < bar {
        let grid = plates.last().copied().unwrap_or(2.5);
        return ((target / grid).round() * grid).max(0.0);
    }
    bar + ((target - bar) / step).round() * step
}

/// Lexicographic "is a strictly better warmup candidate": fewer plates, then
/// closer to the ideal target, then lighter. Kept explicit because f32 isn't
/// `Ord`, and Dart mirrors this exact ordering.
fn candidate_is_better(a: (f32, f32, f32), b: (f32, f32, f32)) -> bool {
    if a.0 != b.0 {
        return a.0 < b.0;
    }
    if (a.1 - b.1).abs() > 1e-6 {
        return a.1 < b.1;
    }
    a.2 < b.2
}

/// A loadable weight near `target` (within one loadable step) that uses the
/// fewest plates per side — i.e. opts for one big plate over several small ones.
/// Clamped to `[min, max]`. This is the generic "simplest step up in plates".
pub fn simplest_loadable_near(
    target: f32,
    bar: f32,
    plates: &[f32],
    min: f32,
    max: f32,
) -> f32 {
    let step = loadable_step(plates);
    let base = snap_loadable(target, bar, plates).clamp(min, max);
    let mut best = base;
    let mut best_key = (
        plate_count_per_side(base, bar, plates),
        (base - target).abs(),
        base,
    );
    for delta in [-step, step] {
        let cand = base + delta;
        if cand < min - 1e-4 || cand > max + 1e-4 {
            continue;
        }
        let cand = cand.clamp(min, max);
        let key = (
            plate_count_per_side(cand, bar, plates),
            (cand - target).abs(),
            cand,
        );
        if candidate_is_better(key, best_key) {
            best = cand;
            best_key = key;
        }
    }
    best
}

/// Snap a stored pound weight to the nearest weight that is exactly loadable in
/// the user's display unit, returned in pounds. This is the "snap to real
/// values" primitive: display(this) is always a clean, loadable number.
#[allow(dead_code)] // rounding primitive kept for callers/tests
pub fn snap_loadable_lb(weight_lb: f32, unit: AppWeightUnit) -> f32 {
    let display = match unit {
        AppWeightUnit::Lb => weight_lb,
        AppWeightUnit::Kg => pounds_to_kg(weight_lb),
    };
    let snapped = snap_loadable(display, bar_weight(unit), plates(unit));
    match unit {
        AppWeightUnit::Lb => snapped,
        AppWeightUnit::Kg => kg_to_pounds(snapped),
    }
}

#[cfg(test)]
mod plate_math_tests {
    use super::*;

    const UNITS: [AppWeightUnit; 2] = [AppWeightUnit::Lb, AppWeightUnit::Kg];

    /// Display-unit sweep from the bar up to a heavy load, on the loadable grid.
    fn loadable_sweep(unit: AppWeightUnit) -> Vec<f32> {
        let bar = bar_weight(unit);
        let step = loadable_step(plates(unit));
        let mut out = Vec::new();
        let mut w = bar;
        while w <= bar + 300.0 {
            out.push(w);
            w += step;
        }
        out
    }

    #[test]
    fn loadable_step_is_two_smallest_plates() {
        assert_eq!(loadable_step(plates(AppWeightUnit::Lb)), 5.0);
        assert_eq!(loadable_step(plates(AppWeightUnit::Kg)), 2.5);
    }

    #[test]
    fn snap_lands_on_exactly_loadable_weights_in_both_units() {
        for unit in UNITS {
            let (bar, pl) = (bar_weight(unit), plates(unit));
            let step = loadable_step(pl);
            // Sweep off-grid targets; every snap must be exactly loadable.
            let mut t = bar;
            while t <= bar + 250.0 {
                for off in [0.0, step * 0.1, step * 0.49, step * 0.5, step * 0.9] {
                    let snapped = snap_loadable(t + off, bar, pl);
                    assert!(
                        plate_count_per_side(snapped, bar, pl).is_finite(),
                        "unit={unit:?} target={} snapped={snapped} is not loadable",
                        t + off
                    );
                }
                t += step;
            }
        }
    }

    #[test]
    fn plates_reconstruct_the_weight_minus_remainder() {
        for unit in UNITS {
            let (bar, pl) = (bar_weight(unit), plates(unit));
            for &w in &loadable_sweep(unit) {
                let (used, rem) = plates_per_side(w, bar, pl);
                let loaded = bar + used.iter().sum::<f32>() * 2.0;
                assert!(
                    (loaded + rem * 2.0 - w).abs() < 1e-3,
                    "unit={unit:?} w={w} loaded={loaded} rem={rem}"
                );
                assert!(rem < 1e-3, "loadable weight {w} left a remainder ({unit:?})");
            }
        }
    }

    #[test]
    fn snap_loadable_lb_round_trips_and_is_idempotent() {
        for unit in UNITS {
            for &lb in &[37.0, 100.0, 133.0, 183.5, 218.0, 271.0, 315.0] {
                let once = snap_loadable_lb(lb, unit);
                // Displaying the snapped pound value gives a clean loadable number.
                let display = match unit {
                    AppWeightUnit::Lb => once,
                    AppWeightUnit::Kg => pounds_to_kg(once),
                };
                assert!(
                    plate_count_per_side(display, bar_weight(unit), plates(unit)).is_finite(),
                    "unit={unit:?} lb={lb} -> {once} lb displays as un-loadable {display}"
                );
                // Idempotent: snapping an already-snapped value is a no-op.
                let twice = snap_loadable_lb(once, unit);
                assert!(
                    (twice - once).abs() < 1e-2,
                    "unit={unit:?} not idempotent: {once} -> {twice}"
                );
            }
        }
    }

    #[test]
    fn simplest_prefers_fewer_plates_and_stays_near_target() {
        for unit in UNITS {
            let (bar, pl) = (bar_weight(unit), plates(unit));
            let step = loadable_step(pl);
            let min = pl.last().copied().unwrap();
            let max = bar + 400.0;
            let mut target = bar;
            while target <= bar + 250.0 {
                let naive = snap_loadable(target, bar, pl).clamp(min, max);
                let simple = simplest_loadable_near(target, bar, pl, min, max);
                // Never more plates than the naive snap.
                assert!(
                    plate_count_per_side(simple, bar, pl)
                        <= plate_count_per_side(naive, bar, pl),
                    "unit={unit:?} target={target}: simple {simple} uses more plates than naive {naive}"
                );
                // Stays within one loadable step of the naive snap (doesn't wander).
                assert!(
                    (simple - naive).abs() <= step + 1e-4,
                    "unit={unit:?} target={target}: simple {simple} too far from {naive}"
                );
                // Always exactly loadable.
                assert!(plate_count_per_side(simple, bar, pl).is_finite());
                target += step;
            }
        }
    }

    #[test]
    fn simplest_opts_for_one_big_plate_over_many_small() {
        // lb: 135 = bar + one 45/side (1 plate). A target of 137.5 (would snap to
        // 137.5 = 45+25+... no: 137.5-45=92.5/2=46.25 not loadable) — use a case
        // where the ±step neighbour is a single big plate.
        let (bar, pl) = (bar_weight(AppWeightUnit::Lb), plates(AppWeightUnit::Lb));
        // 130 -> 45/side is 135 (one plate) vs 130 = 42.5/side (25+10+5+2.5 = 4).
        let simple = simplest_loadable_near(133.0, bar, pl, 5.0, 500.0);
        assert_eq!(simple, 135.0, "should prefer the single-45 load");
        assert_eq!(plate_count_per_side(135.0, bar, pl), 1.0);

        // kg: 22.5 -> one 1.25? no. 25 kg = bar+2.5/side (one 2.5) vs 22.5 = 1.25/side.
        let (kbar, kpl) = (bar_weight(AppWeightUnit::Kg), plates(AppWeightUnit::Kg));
        let ks = simplest_loadable_near(24.0, kbar, kpl, 1.25, 300.0);
        assert_eq!(ks, 25.0);
        assert_eq!(plate_count_per_side(25.0, kbar, kpl), 1.0);
    }
}
