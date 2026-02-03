use dioxus::prelude::*;
use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use wasm_bindgen::prelude::*;

mod db;
use db::Database;

fn main() {
    console_error_panic_hook::set_once();
    dioxus::launch(App);
}

// 5x5 Standard Exercises
const WORKOUT_A: &[&str] = &["Squat", "Bench Press", "Barbell Row"];
const WORKOUT_B: &[&str] = &["Squat", "Overhead Press", "Deadlift"];

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PlannedSet {
    pub id: i64,
    pub exercise: String,
    pub set_number: i32,
    pub weight: f64,
    pub reps: i32,
    pub rest_seconds: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CompletedSet {
    pub id: i64,
    pub exercise: String,
    pub set_number: i32,
    pub weight: f64,
    pub target_reps: i32,
    pub completed_reps: i32,
    pub start_time: f64,
    pub end_time: f64,
    pub rest_seconds: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExerciseConfig {
    pub name: String,
    pub weight: f64,
    pub reps: i32,
    pub sets: i32,
    pub rest_seconds: i32,
}

// Global database
thread_local! {
    static DB: RefCell<Option<Database>> = RefCell::new(None);
}

fn with_db<F, R>(f: F) -> Option<R>
where
    F: FnOnce(&Database) -> R,
{
    DB.with(|db| db.borrow().as_ref().map(f))
}

static PLANNED_SETS: GlobalSignal<Vec<PlannedSet>> = Signal::global(Vec::new);
static COMPLETED_SETS: GlobalSignal<Vec<CompletedSet>> = Signal::global(Vec::new);
static CURRENT_SET_INDEX: GlobalSignal<usize> = Signal::global(|| 0);
static WORKOUT_ACTIVE: GlobalSignal<bool> = Signal::global(|| false);
static SET_IN_PROGRESS: GlobalSignal<bool> = Signal::global(|| false);
static SET_START_TIME: GlobalSignal<f64> = Signal::global(|| 0.0);
static DB_READY: GlobalSignal<bool> = Signal::global(|| false);

#[component]
fn App() -> Element {
    // Initialize database on mount
    use_effect(|| {
        wasm_bindgen_futures::spawn_local(async {
            match Database::new().await {
                Ok(database) => {
                    DB.with(|db| *db.borrow_mut() = Some(database));
                    *DB_READY.write() = true;
                    web_sys::console::log_1(&"Database initialized!".into());
                }
                Err(e) => {
                    web_sys::console::log_1(&format!("DB Error: {:?}", e).into());
                }
            }
        });
    });

    let db_ready = *DB_READY.read();

    rsx! {
        style { {include_str!("../public/style.css")} }
        div { class: "container",
            if !db_ready {
                div { class: "card",
                    h1 { "Loading..." }
                    p { "Initializing database..." }
                }
            } else if *WORKOUT_ACTIVE.read() {
                WorkoutView {}
            } else {
                StartWorkoutView {}
            }
        }
    }
}

#[component]
fn StartWorkoutView() -> Element {
    let mut workout_type = use_signal(|| "A".to_string());
    let mut weights = use_signal(|| {
        vec![
            ("Squat".to_string(), 45.0),
            ("Bench Press".to_string(), 45.0),
            ("Barbell Row".to_string(), 45.0),
            ("Overhead Press".to_string(), 45.0),
            ("Deadlift".to_string(), 45.0),
        ]
    });

    let start_workout = move |_: MouseEvent| {
        let exercises: &[&str] = if *workout_type.read() == "A" {
            WORKOUT_A
        } else {
            WORKOUT_B
        };
        let weight_map = weights.read().clone();

        let configs: Vec<ExerciseConfig> = exercises
            .iter()
            .map(|&name| {
                let weight = weight_map
                    .iter()
                    .find(|(n, _)| n == name)
                    .map(|(_, w)| *w)
                    .unwrap_or(45.0);

                // Deadlift is 1x5, everything else is 5x5
                let sets = if name == "Deadlift" { 1 } else { 5 };

                ExerciseConfig {
                    name: name.to_string(),
                    weight,
                    reps: 5,
                    sets,
                    rest_seconds: 180, // 3 minutes rest
                }
            })
            .collect();

        start_workout_with_config(&configs);
    };

    let download_db = move |_| {
        with_db(|db| {
            web_sys::console::log_1(&"Exporting database...".into());

            // 1. Get binary data
            let data = db.export();

            // Debug: Check if data actually exists
            let size = data.length();
            web_sys::console::log_1(&format!("Database size: {} bytes", size).into());

            if size == 0 {
                web_sys::console::error_1(&"Warning: Exported database is empty!".into());
                return;
            }

            // 2. Create Blob with specific MIME type for SQLite
            let array = js_sys::Array::of1(&data);
            let options = web_sys::BlobPropertyBag::new();
            options.set_type("application/x-sqlite3");

            let blob = web_sys::Blob::new_with_u8_array_sequence_and_options(&array, &options)
                .expect("Failed to create blob");

            // 3. Trigger Download
            let url =
                web_sys::Url::create_object_url_with_blob(&blob).expect("Failed to create URL");

            let window = web_sys::window().unwrap();
            let document = window.document().unwrap();
            let a = document.create_element("a").unwrap();

            use wasm_bindgen::JsCast;
            let a: web_sys::HtmlAnchorElement = a.unchecked_into();

            a.set_href(&url);
            a.set_download("lift_progress.sqlite");
            a.click();

            web_sys::Url::revoke_object_url(&url).unwrap();
        });
    };

    let exercises: &[&str] = if *workout_type.read() == "A" {
        WORKOUT_A
    } else {
        WORKOUT_B
    };

    rsx! {
        div { class: "card",
            h1 { "Lift - 5x5 Workout" }

            div { class: "form-group",
                label { "Workout Type" }
                div { class: "button-group",
                    button {
                        class: if *workout_type.read() == "A" { "selected" } else { "" },
                        onclick: move |_| workout_type.set("A".to_string()),
                        "Workout A"
                    }
                    button {
                        class: if *workout_type.read() == "B" { "selected" } else { "" },
                        onclick: move |_| workout_type.set("B".to_string()),
                        "Workout B"
                    }
                }

            }

            h2 { "Exercises" }
            for exercise in exercises.iter() {
                {
                    let name = exercise.to_string();
                    let current_weight = weights.read()
                        .iter()
                        .find(|(n, _)| n == &name)
                        .map(|(_, w)| *w)
                        .unwrap_or(45.0);
                    let sets = if name == "Deadlift" { 1 } else { 5 };

                    rsx! {
                        div { class: "exercise-config",
                            div { class: "exercise-name", "{name}" }
                            div { class: "exercise-details",
                                span { "{sets}x5 @ " }
                                input {
                                    r#type: "number",
                                    class: "weight-input",
                                    value: "{current_weight}",
                                    oninput: {
                                        let name = name.clone();
                                        move |e: FormEvent| {
                                            if let Ok(w) = e.value().parse::<f64>() {
                                                let mut w_list = weights.read().clone();
                                                if let Some(entry) = w_list.iter_mut().find(|(n, _)| n == &name) {
                                                    entry.1 = w;
                                                }
                                                weights.set(w_list);
                                            }
                                        }
                                    },
                                }
                                span { " lbs" }
                            }
                        }
                    }
                }
            }

            button {
                class: "start-button",
                onclick: start_workout,
                "Start Workout"
            }

            button {
                class: "download-button",
                style: "margin-top: 10px; background-color: #666;", // Simple inline style for separation
                onclick: download_db,
                "Download Database Backup"
            }
        }
    }
}

fn start_workout_with_config(configs: &[ExerciseConfig]) {
    let mut planned_sets = Vec::new();

    for config in configs {
        for set_num in 1..=config.sets {
            planned_sets.push(PlannedSet {
                id: 0,
                exercise: config.name.clone(),
                set_number: set_num,
                weight: config.weight,
                reps: config.reps,
                rest_seconds: config.rest_seconds,
            });
        }
    }

    // Save to database
    with_db(|db| {
        db.clear_planned_sets();
        for set in &planned_sets {
            db.insert_planned_set(set);
        }
    });

    // Update state
    *PLANNED_SETS.write() = with_db(|db| db.get_planned_sets()).unwrap_or_default();
    *COMPLETED_SETS.write() = Vec::new();
    *CURRENT_SET_INDEX.write() = 0;
    *WORKOUT_ACTIVE.write() = true;
    *SET_IN_PROGRESS.write() = false;
}

#[component]
fn WorkoutView() -> Element {
    let planned_sets = PLANNED_SETS.read().clone();
    let completed_sets = COMPLETED_SETS.read().clone();
    let current_index = *CURRENT_SET_INDEX.read();
    let set_in_progress = *SET_IN_PROGRESS.read();

    let current_set = planned_sets.get(current_index).cloned();
    let all_done = current_index >= planned_sets.len();

    let start_set = move |_: MouseEvent| {
        *SET_START_TIME.write() = js_sys::Date::now();
        *SET_IN_PROGRESS.write() = true;
    };

    let mut completed_reps = use_signal(|| 5);

    let finish_set = {
        let current_set = current_set.clone();
        move |_: MouseEvent| {
            if let Some(ref set) = current_set {
                let completed = CompletedSet {
                    id: 0,
                    exercise: set.exercise.clone(),
                    set_number: set.set_number,
                    weight: set.weight,
                    target_reps: set.reps,
                    completed_reps: *completed_reps.read(),
                    start_time: *SET_START_TIME.read(),
                    end_time: js_sys::Date::now(),
                    rest_seconds: set.rest_seconds,
                };

                with_db(|db| db.insert_completed_set(&completed));

                COMPLETED_SETS.write().push(completed);
                *CURRENT_SET_INDEX.write() = current_index + 1;
                *SET_IN_PROGRESS.write() = false;
                completed_reps.set(5);
            }
        }
    };

    let cancel_workout = move |_: MouseEvent| {
        *WORKOUT_ACTIVE.write() = false;
        *PLANNED_SETS.write() = Vec::new();
        *COMPLETED_SETS.write() = Vec::new();
        *CURRENT_SET_INDEX.write() = 0;
    };

    rsx! {
        div { class: "card",
            h1 { "Workout in Progress" }

            // Progress
            p { class: "progress",
                "Set {current_index + 1} of {planned_sets.len()}"
            }

            if all_done {
                div { class: "workout-complete",
                    h2 { "Workout Complete!" }
                    p { "You finished all {planned_sets.len()} sets." }
                    button {
                        onclick: cancel_workout,
                        "Done"
                    }
                }
            } else if let Some(set) = current_set {
                div { class: "current-set",
                    h2 { "{set.exercise}" }
                    p { class: "set-details",
                        "Set {set.set_number}: {set.weight} lbs x {set.reps} reps"
                    }

                    if !set_in_progress {
                        button {
                            class: "start-button",
                            onclick: start_set,
                            "Start Set"
                        }
                    } else {
                        div { class: "rep-input",
                            label { "Completed Reps:" }
                            div { class: "rep-buttons",
                                for i in 0..=5 {
                                    button {
                                        class: if *completed_reps.read() == i { "selected" } else { "" },
                                        onclick: move |_| completed_reps.set(i),
                                        "{i}"
                                    }
                                }
                            }
                        }
                        button {
                            class: "finish-button",
                            onclick: finish_set,
                            "Finish Set"
                        }
                    }
                }
            }

            // Completed sets summary
            if !completed_sets.is_empty() {
                h3 { "Completed" }
                div { class: "completed-list",
                    for completed in completed_sets.iter().rev().take(5) {
                        div { class: "completed-item",
                            "{completed.exercise} Set {completed.set_number}: "
                            "{completed.completed_reps}/{completed.target_reps} @ {completed.weight}lbs"
                        }
                    }
                }
            }

            button {
                class: "cancel-button",
                onclick: cancel_workout,
                "Cancel Workout"
            }
        }
    }
}
