use crate::{CompletedSet, PlannedSet};
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast; // Required for unchecked_into

#[wasm_bindgen]
extern "C" {
    // This defines the type "SqlJsDatabase" to Rust.
    // It's just a label we put on the JS object.
    type SqlJsDatabase;

    #[wasm_bindgen(method, js_name = "run")]
    fn run(this: &SqlJsDatabase, sql: &str);

    #[wasm_bindgen(method, js_name = "run")]
    fn run_with_params(this: &SqlJsDatabase, sql: &str, params: &JsValue);

    #[wasm_bindgen(method, js_name = "exec")]
    fn exec(this: &SqlJsDatabase, sql: &str) -> js_sys::Array;

    #[wasm_bindgen(method, js_name = "export")]
    fn export(this: &SqlJsDatabase) -> js_sys::Uint8Array;
}

pub struct Database {
    db: SqlJsDatabase,
}

impl Database {
    pub async fn new() -> Result<Self, JsValue> {
        // 1. Configure sql.js to find the WASM file on the CDN
        let config = js_sys::Object::new();
        let locate_file = Closure::wrap(Box::new(|filename: String| -> String {
            format!(
                "https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.10.3/{}",
                filename
            )
        }) as Box<dyn Fn(String) -> String>);

        js_sys::Reflect::set(
            &config,
            &"locateFile".into(),
            locate_file.as_ref().unchecked_ref(),
        )?;
        locate_file.forget(); // Keep closure alive

        // 2. Initialize the library
        let window = web_sys::window().expect("no global `window` exists");
        let init_fn = js_sys::Reflect::get(&window, &"initSqlJs".into())?;

        if init_fn.is_undefined() {
            return Err(JsValue::from_str(
                "initSqlJs not found. Ensure script tag is in index.html",
            ));
        }

        let init_fn: js_sys::Function = init_fn.unchecked_into();
        let promise = init_fn.call1(&JsValue::NULL, &config)?;
        let sql_js_val =
            wasm_bindgen_futures::JsFuture::from(js_sys::Promise::from(promise)).await?;

        // 3. Create the Database
        let db_class = js_sys::Reflect::get(&sql_js_val, &"Database".into())?;
        let db_constructor: js_sys::Function = db_class.unchecked_into();
        let db_instance = js_sys::Reflect::construct(&db_constructor, &js_sys::Array::new())?;

        // --- THE FIX IS HERE ---
        // We use unchecked_into() instead of dyn_into().
        // We are telling Rust: "Trust me, this IS a SqlJsDatabase object."
        let db: SqlJsDatabase = db_instance.unchecked_into();

        let database = Database { db };
        database.init_tables();

        Ok(database)
    }

    fn init_tables(&self) {
        self.db.run(
            "CREATE TABLE IF NOT EXISTS planned_sets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                exercise TEXT NOT NULL,
                set_number INTEGER NOT NULL,
                weight REAL NOT NULL,
                reps INTEGER NOT NULL,
                rest_seconds INTEGER NOT NULL
            )",
        );

        self.db.run(
            "CREATE TABLE IF NOT EXISTS completed_sets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                exercise TEXT NOT NULL,
                set_number INTEGER NOT NULL,
                weight REAL NOT NULL,
                target_reps INTEGER NOT NULL,
                completed_reps INTEGER NOT NULL,
                start_time REAL NOT NULL,
                end_time REAL NOT NULL,
                rest_seconds INTEGER NOT NULL
            )",
        );
    }

    // --- Helpers ---

    pub fn clear_planned_sets(&self) {
        self.db.run("DELETE FROM planned_sets");
    }

    pub fn insert_planned_set(&self, set: &PlannedSet) {
        let params = js_sys::Array::new();
        params.push(&JsValue::from_str(&set.exercise));
        params.push(&JsValue::from_f64(set.set_number as f64));
        params.push(&JsValue::from_f64(set.weight));
        params.push(&JsValue::from_f64(set.reps as f64));
        params.push(&JsValue::from_f64(set.rest_seconds as f64));

        self.db.run_with_params(
            "INSERT INTO planned_sets (exercise, set_number, weight, reps, rest_seconds) VALUES (?, ?, ?, ?, ?)",
            &params
        );
    }

    pub fn get_planned_sets(&self) -> Vec<PlannedSet> {
        let result = self.db.exec("SELECT id, exercise, set_number, weight, reps, rest_seconds FROM planned_sets ORDER BY id");
        self.parse_planned_sets(result)
    }

    fn parse_planned_sets(&self, result: js_sys::Array) -> Vec<PlannedSet> {
        let mut sets = Vec::new();
        if result.length() == 0 {
            return sets;
        }

        let first = result.get(0);
        let values = js_sys::Reflect::get(&first, &"values".into()).unwrap();
        let values: js_sys::Array = values.unchecked_into();

        for i in 0..values.length() {
            let row: js_sys::Array = values.get(i).unchecked_into();
            sets.push(PlannedSet {
                id: row.get(0).as_f64().unwrap_or(0.0) as i64,
                exercise: row.get(1).as_string().unwrap_or_default(),
                set_number: row.get(2).as_f64().unwrap_or(0.0) as i32,
                weight: row.get(3).as_f64().unwrap_or(0.0),
                reps: row.get(4).as_f64().unwrap_or(0.0) as i32,
                rest_seconds: row.get(5).as_f64().unwrap_or(0.0) as i32,
            });
        }
        sets
    }

    pub fn insert_completed_set(&self, set: &CompletedSet) {
        let params = js_sys::Array::new();
        params.push(&JsValue::from_str(&set.exercise));
        params.push(&JsValue::from_f64(set.set_number as f64));
        params.push(&JsValue::from_f64(set.weight));
        params.push(&JsValue::from_f64(set.target_reps as f64));
        params.push(&JsValue::from_f64(set.completed_reps as f64));
        params.push(&JsValue::from_f64(set.start_time));
        params.push(&JsValue::from_f64(set.end_time));
        params.push(&JsValue::from_f64(set.rest_seconds as f64));

        self.db.run_with_params(
            "INSERT INTO completed_sets (exercise, set_number, weight, target_reps, completed_reps, start_time, end_time, rest_seconds) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            &params
        );
    }

    pub fn export(&self) -> js_sys::Uint8Array {
        // sql.js provides an .export() method that returns a Uint8Array
        self.db.export()
    }

    pub fn get_completed_sets(&self) -> Vec<CompletedSet> {
        let result = self.db.exec("SELECT id, exercise, set_number, weight, target_reps, completed_reps, start_time, end_time, rest_seconds FROM completed_sets ORDER BY id DESC");
        self.parse_completed_sets(result)
    }

    fn parse_completed_sets(&self, result: js_sys::Array) -> Vec<CompletedSet> {
        let mut sets = Vec::new();
        if result.length() == 0 {
            return sets;
        }

        let first = result.get(0);
        let values = js_sys::Reflect::get(&first, &"values".into()).unwrap();
        let values: js_sys::Array = values.unchecked_into();

        for i in 0..values.length() {
            let row: js_sys::Array = values.get(i).unchecked_into();
            sets.push(CompletedSet {
                id: row.get(0).as_f64().unwrap_or(0.0) as i64,
                exercise: row.get(1).as_string().unwrap_or_default(),
                set_number: row.get(2).as_f64().unwrap_or(0.0) as i32,
                weight: row.get(3).as_f64().unwrap_or(0.0),
                target_reps: row.get(4).as_f64().unwrap_or(0.0) as i32,
                completed_reps: row.get(5).as_f64().unwrap_or(0.0) as i32,
                start_time: row.get(6).as_f64().unwrap_or(0.0),
                end_time: row.get(7).as_f64().unwrap_or(0.0),
                rest_seconds: row.get(8).as_f64().unwrap_or(0.0) as i32,
            });
        }
        sets
    }
}
