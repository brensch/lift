//! Cross-regime coverage of the layoff deload policy.
//!
//! Every regime implements `apply_temporal_adjustments_for_proposal` with the
//! same thresholds. Testing them together pins the policy as a whole, and means
//! a new regime that forgets to implement it (the trait has a no-op default)
//! fails here rather than silently never deloading.

use std::collections::HashMap;

use crate::program_state::{FieldVal, StatePayload};
use crate::regimes::{catalog_regime_types, get_regime};
use schlift::workout::v1::RegimeType;

const DAY: i64 = 24 * 3600;
const LAST_SESSION: i64 = 1_000_000;

/// Float fields in a regime's state are its weights (working weights, T1/T2
/// weights, training maxes). Comparing them wholesale keeps this test agnostic
/// about each regime's key names.
fn float_fields(state: &StatePayload) -> HashMap<String, f32> {
    state
        .iter()
        .filter_map(|(k, v)| match v {
            FieldVal::Float(f) => Some((k.clone(), *f as f32)),
            _ => None,
        })
        .collect()
}

fn adjusted_after(regime_type: RegimeType, days: i64) -> HashMap<String, f32> {
    let regime = get_regime(regime_type);
    let state = regime.default_state();
    let adjusted = regime.apply_temporal_adjustments_for_proposal(
        &state,
        LAST_SESSION,
        LAST_SESSION + days * DAY,
    );
    float_fields(&adjusted)
}

fn baseline(regime_type: RegimeType) -> HashMap<String, f32> {
    float_fields(&get_regime(regime_type).default_state())
}

#[test]
fn every_catalogued_regime_implements_a_layoff_deload() {
    for regime_type in catalog_regime_types() {
        let base = baseline(regime_type);
        let after_60 = adjusted_after(regime_type, 60);

        assert!(
            !base.is_empty(),
            "{regime_type:?} default state has no float weight fields to deload"
        );

        let any_reduced = base
            .iter()
            .any(|(k, v)| after_60.get(k).is_some_and(|a| *a < *v));

        assert!(
            any_reduced,
            "{regime_type:?} does not reduce any weight after 60 days away. The \
             WorkoutRegime trait's default apply_temporal_adjustments_for_proposal \
             is a no-op — implement it for this regime."
        );
    }
}

#[test]
fn a_gap_under_two_weeks_never_changes_anything() {
    for regime_type in catalog_regime_types() {
        let base = baseline(regime_type);
        for days in [0, 1, 6, 13] {
            assert_eq!(
                adjusted_after(regime_type, days),
                base,
                "{regime_type:?} must not adjust anything after only {days} days"
            );
        }
    }
}

#[test]
fn the_deload_has_exactly_two_bands_at_fourteen_and_thirty_days() {
    for regime_type in catalog_regime_types() {
        let base = baseline(regime_type);

        let band_90 = adjusted_after(regime_type, 14);
        let band_80 = adjusted_after(regime_type, 30);

        assert_ne!(
            band_90, base,
            "{regime_type:?} should start deloading at 14 days"
        );
        assert_ne!(
            band_80, band_90,
            "{regime_type:?} should deload further at 30 days"
        );

        // Flat within each band.
        assert_eq!(adjusted_after(regime_type, 20), band_90, "{regime_type:?}");
        assert_eq!(adjusted_after(regime_type, 29), band_90, "{regime_type:?}");
        assert_eq!(adjusted_after(regime_type, 45), band_80, "{regime_type:?}");
        assert_eq!(adjusted_after(regime_type, 365), band_80, "{regime_type:?}");
    }
}

#[test]
fn deloads_are_monotonic_and_never_increase_a_weight() {
    for regime_type in catalog_regime_types() {
        let base = baseline(regime_type);
        let band_90 = adjusted_after(regime_type, 14);
        let band_80 = adjusted_after(regime_type, 30);

        for (key, original) in &base {
            let at_90 = band_90[key];
            let at_80 = band_80[key];

            assert!(
                at_90 <= *original,
                "{regime_type:?}.{key}: 14-day deload raised the weight \
                 ({original} -> {at_90})"
            );
            assert!(
                at_80 <= at_90,
                "{regime_type:?}.{key}: 30-day deload is lighter than the 14-day one \
                 ({at_90} -> {at_80})"
            );
        }
    }
}

#[test]
fn deloaded_weights_stay_loadable_and_above_an_empty_bar() {
    for regime_type in catalog_regime_types() {
        for days in [14, 30, 400] {
            for (key, weight) in adjusted_after(regime_type, days) {
                assert!(
                    weight > 0.0,
                    "{regime_type:?}.{key} deloaded to {weight} after {days} days"
                );
                // All three regimes round to 2.5 lb or coarser.
                let steps = weight / 2.5;
                assert!(
                    (steps - steps.round()).abs() < 1e-3,
                    "{regime_type:?}.{key} deloaded to {weight}, which is not a \
                     loadable multiple of 2.5 lb"
                );
            }
        }
    }
}

/// A brand new user has no history, so there is nothing to deload from.
#[test]
fn a_user_with_no_previous_session_is_never_deloaded() {
    for regime_type in catalog_regime_types() {
        let regime = get_regime(regime_type);
        let state = regime.default_state();
        let adjusted = regime.apply_temporal_adjustments_for_proposal(&state, 0, LAST_SESSION);
        assert_eq!(
            float_fields(&adjusted),
            float_fields(&state),
            "{regime_type:?} deloaded a user who has never trained"
        );
    }
}
