//! The template library: templates/library.yaml, embedded at build time.
//! The server sends its copy to every phone on sync; a user's library
//! templates follow it (coupled) until they clone one. The copy built into
//! the app stands in before the first sync. The file is validated by
//! `cargo test`. The file's ready-made rotations (`plans`) are read from
//! the copy built in. See docs/architecture/data-model.md, "Template
//! library".

use crate::pb::{Exercise, LibraryPlan, LibraryTemplate};
use serde::Deserialize;
use std::collections::HashSet;
use std::sync::OnceLock;

const SOURCE: &str = include_str!("../../templates/library.yaml");

#[derive(Deserialize)]
struct File {
    groups: Vec<Group>,
    templates: Vec<Entry>,
    #[serde(default)]
    plans: Vec<Plan>,
}

#[derive(Deserialize)]
struct Plan {
    id: String,
    name: String,
    #[serde(default)]
    blurb: String,
    templates: Vec<String>,
}

#[derive(Deserialize)]
struct Group {
    key: String,
    label: String,
}

#[derive(Deserialize)]
struct Entry {
    id: String,
    name: String,
    group: String,
    #[serde(default)]
    blurb: String,
    #[serde(default)]
    default: bool,
    exercises: Vec<String>,
}

/// Parses and validates the embedded file. An error names the entry.
pub fn load() -> Result<Vec<LibraryTemplate>, String> {
    parse(SOURCE).map(|(templates, _)| templates)
}

/// The embedded file's ready-made plans, validated against its templates.
pub fn load_plans() -> Result<Vec<LibraryPlan>, String> {
    parse(SOURCE).map(|(_, plans)| plans)
}

fn snake_case(id: &str) -> bool {
    !id.is_empty()
        && id
            .chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_')
}

fn parse(text: &str) -> Result<(Vec<LibraryTemplate>, Vec<LibraryPlan>), String> {
    let file: File =
        serde_yaml::from_str(text).map_err(|e| format!("templates/library.yaml: {e}"))?;
    let mut seen = HashSet::new();
    let mut out = Vec::with_capacity(file.templates.len());
    for entry in file.templates {
        let id = entry.id.trim();
        if !snake_case(id) {
            return Err(format!("template id {id:?} must be lower_snake_case"));
        }
        if !seen.insert(id.to_string()) {
            return Err(format!("template id {id:?} appears twice"));
        }
        if entry.name.trim().is_empty() {
            return Err(format!("template {id}: empty name"));
        }
        let group = file
            .groups
            .iter()
            .find(|g| g.key == entry.group)
            .ok_or_else(|| format!("template {id}: unknown group {:?}", entry.group))?;
        if entry.exercises.is_empty() {
            return Err(format!("template {id}: no exercises"));
        }
        let mut exercises = Vec::with_capacity(entry.exercises.len());
        for name in &entry.exercises {
            let exercise = Exercise::from_str_name(&format!("EXERCISE_{name}"))
                .filter(|e| *e != Exercise::Unspecified)
                .ok_or_else(|| format!("template {id}: unknown exercise {name:?}"))?;
            if exercises.contains(&(exercise as i32)) {
                return Err(format!("template {id}: exercise {name:?} listed twice"));
            }
            exercises.push(exercise as i32);
        }
        out.push(LibraryTemplate {
            id: id.to_string(),
            name: entry.name.trim().to_string(),
            blurb: entry.blurb.trim().to_string(),
            group_label: group.label.clone(),
            exercises,
            is_default: entry.default,
        });
    }
    if out.is_empty() {
        return Err("templates/library.yaml has no templates".into());
    }
    if !out.iter().any(|t| t.is_default) {
        return Err("templates/library.yaml marks nothing default: true".into());
    }
    let plans = parse_plans(file.plans, &out)?;
    Ok((out, plans))
}

/// Each plan: a lower_snake_case id of its own, a name, and one or more
/// distinct ids of [templates].
fn parse_plans(
    plans: Vec<Plan>,
    templates: &[LibraryTemplate],
) -> Result<Vec<LibraryPlan>, String> {
    let mut seen = HashSet::new();
    let mut out = Vec::with_capacity(plans.len());
    for plan in plans {
        let id = plan.id.trim();
        if !snake_case(id) {
            return Err(format!("plan id {id:?} must be lower_snake_case"));
        }
        if !seen.insert(id.to_string()) {
            return Err(format!("plan id {id:?} appears twice"));
        }
        if plan.name.trim().is_empty() {
            return Err(format!("plan {id}: empty name"));
        }
        if plan.templates.is_empty() {
            return Err(format!("plan {id}: no templates"));
        }
        let mut library_ids: Vec<String> = Vec::with_capacity(plan.templates.len());
        for template in &plan.templates {
            let template = template.trim();
            if !templates.iter().any(|t| t.id == template) {
                return Err(format!("plan {id}: unknown template {template:?}"));
            }
            if library_ids.iter().any(|t| t == template) {
                return Err(format!("plan {id}: template {template:?} listed twice"));
            }
            library_ids.push(template.to_string());
        }
        out.push(LibraryPlan {
            id: id.to_string(),
            name: plan.name.trim().to_string(),
            blurb: plan.blurb.trim().to_string(),
            library_ids,
        });
    }
    Ok(out)
}

/// The validated library, in file order. Startup has already run [`load`]
/// and refused to boot on an error, so this never fails in a running server.
pub fn library() -> &'static [LibraryTemplate] {
    static LIBRARY: OnceLock<Vec<LibraryTemplate>> = OnceLock::new();
    LIBRARY.get_or_init(|| load().expect("templates/library.yaml is validated at startup"))
}

/// The validated ready-made plans, in file order.
pub fn plans() -> &'static [LibraryPlan] {
    static PLANS: OnceLock<Vec<LibraryPlan>> = OnceLock::new();
    PLANS.get_or_init(|| load_plans().expect("templates/library.yaml is validated at startup"))
}

pub fn find(id: &str) -> Option<&'static LibraryTemplate> {
    library().iter().find(|t| t.id == id)
}

/// The entries marked `default: true`: what a client that never asked
/// (or an onboarding request that names nothing) gets copied in.
pub fn defaults() -> Vec<&'static LibraryTemplate> {
    library().iter().filter(|t| t.is_default).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn embedded_library_is_valid() {
        let library = load().expect("templates/library.yaml must validate");
        assert!(library.len() >= 6);
        assert!(library.iter().any(|t| t.id == "stronglifts_a"));
        assert!(library.iter().any(|t| t.name == "Butt Stuff"));
        for t in &library {
            assert!(!t.exercises.is_empty(), "{} has no exercises", t.id);
        }
        // Defaults keep the pre-library behaviour: at least one full body
        // template lands for a client that never asked.
        assert!(defaults().iter().any(|t| t.id == "stronglifts_a"));
    }

    #[test]
    fn rejects_unknown_exercise_and_duplicate_id() {
        let bad = "groups: [{key: g, label: G}]\ntemplates:\n  - {id: a, name: A, group: g, exercises: [NOT_A_LIFT]}\n";
        assert!(parse(bad).unwrap_err().contains("unknown exercise"));
        let dup = "groups: [{key: g, label: G}]\ntemplates:\n  - {id: a, name: A, group: g, default: true, exercises: [SQUAT]}\n  - {id: a, name: B, group: g, exercises: [SQUAT]}\n";
        assert!(parse(dup).unwrap_err().contains("twice"));
        let group = "groups: [{key: g, label: G}]\ntemplates:\n  - {id: a, name: A, group: nope, exercises: [SQUAT]}\n";
        assert!(parse(group).unwrap_err().contains("unknown group"));
    }

    #[test]
    fn embedded_plans_are_valid() {
        let plans = load_plans().expect("templates/library.yaml plans must validate");
        let ids = |id: &str| {
            plans
                .iter()
                .find(|p| p.id == id)
                .unwrap_or_else(|| panic!("plan {id}"))
                .library_ids
                .clone()
        };
        assert_eq!(ids("stronglifts"), ["stronglifts_a", "stronglifts_b"]);
        assert_eq!(ids("upper_lower"), ["upper", "lower"]);
        assert_eq!(ids("push_pull_legs"), ["push", "pull", "legs"]);
        assert_eq!(ids("full_body"), ["full_body"]);
        for plan in &plans {
            assert!(
                !plan.name.is_empty() && !plan.blurb.is_empty(),
                "{}",
                plan.id
            );
            for id in &plan.library_ids {
                assert!(find(id).is_some(), "plan {} names {id}", plan.id);
            }
        }
    }

    #[test]
    fn rejects_a_plan_naming_an_unknown_or_repeated_template() {
        let head = "groups: [{key: g, label: G}]\ntemplates:\n  - {id: a, name: A, group: g, default: true, exercises: [SQUAT]}\n";
        let unknown = format!("{head}plans:\n  - {{id: p, name: P, templates: [a, nope]}}\n");
        assert!(parse(&unknown).unwrap_err().contains("unknown template"));
        let twice = format!("{head}plans:\n  - {{id: p, name: P, templates: [a, a]}}\n");
        assert!(parse(&twice).unwrap_err().contains("listed twice"));
        let empty = format!("{head}plans:\n  - {{id: p, name: P, templates: []}}\n");
        assert!(parse(&empty).unwrap_err().contains("no templates"));
        let dup = format!(
            "{head}plans:\n  - {{id: p, name: P, templates: [a]}}\n  - {{id: p, name: Q, templates: [a]}}\n"
        );
        assert!(parse(&dup).unwrap_err().contains("appears twice"));
        // No plans at all is fine.
        assert!(parse(head).unwrap().1.is_empty());
    }
}
