//! What an exercise loads like, from the program: the weight a lift never
//! done opens at, the step its weights snap to and climb by, and real plate
//! maths for barbells on the program's bar and plates. Weights are pounds
//! in and out; each is rounded in the user's unit, so it reads as a clean
//! loadable number in that unit.

use super::{EquipmentStyle, Muscle, Program};
use crate::weight_units::{round_to_unit_increment, snap_loadable, AppWeightUnit};

impl Program {
    pub fn equipment_of(&self, key: &str) -> EquipmentStyle {
        self.exercise_or_unknown(key).equipment
    }

    pub fn is_bodyweight(&self, key: &str) -> bool {
        self.equipment_of(key) == EquipmentStyle::Bodyweight
    }

    /// The muscles it trains, primary mover first.
    pub fn muscles(&self, key: &str) -> &[Muscle] {
        &self.exercise_or_unknown(key).muscles
    }

    pub fn primary_muscle(&self, key: &str) -> Option<Muscle> {
        self.muscles(key).first().copied()
    }

    /// What one working set counts for each muscle it trains: 1.0 for the
    /// primary, `volume.secondary_credit` for each after it.
    pub fn credit<'a>(&'a self, key: &str) -> impl Iterator<Item = (Muscle, f32)> + 'a {
        let secondary = self.volume.secondary_credit;
        self.muscles(key)
            .iter()
            .enumerate()
            .map(move |(i, m)| (*m, if i == 0 { 1.0 } else { secondary }))
    }

    /// The weight a lift never done opens at: the empty bar (or the
    /// barbell's opener, never under the bar), the equipment's opener, or
    /// nothing for bodyweight.
    pub fn opener_lb(&self, key: &str, unit: AppWeightUnit) -> f32 {
        let style = self.equipment_of(key);
        let loading = self.loading(style);
        match style {
            EquipmentStyle::Barbell => {
                let bar = self.equipment.plates.bar(unit);
                unit.to_lb(loading.opener.map_or(bar, |o| o.get(unit).max(bar)))
            }
            EquipmentStyle::Bodyweight => 0.0,
            _ => loading.opener.map_or(0.0, |o| unit.to_lb(o.get(unit))),
        }
    }

    /// The equipment's step in `unit`'s own scale.
    fn step_in_unit(&self, key: &str, unit: AppWeightUnit) -> f32 {
        self.loading(self.equipment_of(key)).step.get(unit)
    }

    /// One step of weight (lb): what a lift goes up by. 0 for bodyweight,
    /// which goes up in reps.
    pub fn step_lb(&self, key: &str, unit: AppWeightUnit) -> f32 {
        match self.equipment_of(key) {
            EquipmentStyle::Bodyweight => 0.0,
            _ => unit.to_lb(self.step_in_unit(key, unit)),
        }
    }

    /// The nearest weight the lift can load: plate maths on the bar for
    /// barbells (never under the opener), the equipment's step for the
    /// rest; bodyweight's added weight as given.
    pub fn snap_lb(&self, key: &str, weight_lb: f32, unit: AppWeightUnit) -> f32 {
        if weight_lb <= 0.0 {
            return 0.0;
        }
        match self.equipment_of(key) {
            EquipmentStyle::Barbell => self
                .snap_on_bar_lb(weight_lb, unit)
                .max(self.opener_lb(key, unit)),
            EquipmentStyle::Bodyweight => weight_lb,
            _ => round_to_unit_increment(weight_lb, unit, self.step_in_unit(key, unit)),
        }
    }

    /// The heaviest weight at or under `weight_lb` the lift can load (never
    /// under the opener or one step).
    pub fn snap_down_lb(&self, key: &str, weight_lb: f32, unit: AppWeightUnit) -> f32 {
        let step = self.step_lb(key, unit);
        let snapped = self.snap_lb(key, weight_lb, unit);
        if step <= 0.0 {
            return snapped;
        }
        let down = if snapped <= weight_lb + 1e-3 {
            snapped
        } else {
            self.snap_lb(key, snapped - step, unit)
        };
        down.max(self.snap_lb(key, step, unit))
    }

    /// The nearest weight exactly loadable on the bar from the plates, in
    /// pounds.
    pub fn snap_on_bar_lb(&self, weight_lb: f32, unit: AppWeightUnit) -> f32 {
        let plates = &self.equipment.plates;
        unit.to_lb(snap_loadable(
            unit.from_lb(weight_lb),
            plates.bar(unit),
            plates.plates(unit),
        ))
    }
}
