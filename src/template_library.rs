//! The template library: templates/library.yaml, embedded at build time.
//! Users tick entries during onboarding and add more later; each add
//! copies the entry into their own templates (tagged with `library_id`),
//! after which it is theirs to edit. The file is validated by `cargo test`
//! and again at startup, then mirrored into the `template_library` table
//! that `ListTemplateLibrary` serves.

use schlift::workout::v1::{Exercise, LibraryTemplate};
use serde::Deserialize;
use std::collections::HashSet;
use std::sync::OnceLock;

const SOURCE: &str = include_str!("../templates/library.yaml");

#[derive(Deserialize)]
struct File {
    groups: Vec<Group>,
    templates: Vec<Entry>,
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
    parse(SOURCE)
}

fn parse(text: &str) -> Result<Vec<LibraryTemplate>, String> {
    let file: File =
        serde_yaml::from_str(text).map_err(|e| format!("templates/library.yaml: {e}"))?;
    let mut seen = HashSet::new();
    let mut out = Vec::with_capacity(file.templates.len());
    for entry in file.templates {
        let id = entry.id.trim();
        if id.is_empty()
            || id
                .chars()
                .any(|c| !(c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_'))
        {
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
            group_key: group.key.clone(),
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
    Ok(out)
}

/// The validated library, in file order. Startup has already run [`load`]
/// and refused to boot on an error, so this never fails in a running server.
pub fn library() -> &'static [LibraryTemplate] {
    static LIBRARY: OnceLock<Vec<LibraryTemplate>> = OnceLock::new();
    LIBRARY.get_or_init(|| load().expect("templates/library.yaml is validated at startup"))
}

pub fn find(id: &str) -> Option<&'static LibraryTemplate> {
    library().iter().find(|t| t.id == id)
}

/// The entries marked `default: true`: what a client that never asked
/// (or an onboarding request that names nothing) gets copied in.
pub fn defaults() -> Vec<&'static LibraryTemplate> {
    library().iter().filter(|t| t.is_default).collect()
}

/// Kept for the one-time flat-workouts migration: name and exercises of
/// the default entries.
pub fn default_templates() -> Vec<(String, Vec<Exercise>)> {
    defaults()
        .into_iter()
        .map(|t| {
            (
                t.name.clone(),
                t.exercises
                    .iter()
                    .filter_map(|e| Exercise::try_from(*e).ok())
                    .collect(),
            )
        })
        .collect()
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
        assert!(defaults().iter().any(|t| t.id == "full_body"));
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
}
