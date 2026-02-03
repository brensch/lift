use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use crate::{PlannedSet, CompletedSet};

// --- FFI Definition for sql.js ---
#[wasm_bindgen]
extern "C" {
    // Defines the shape of the Database object returned by sql.js
    // We say it extends Object so we can use standard JS object methods if needed
    #[wasm_bindgen(extends = js_sys::Object)]
    type SqlJsDatabase;

    // 'catch' converts JS exceptions (like SQL syntax errors) into Rust Result::Err
    #[wasm_bindgen(method, js_name = "run", catch)]
    fn run(this: &SqlJsDatabase, sql: &str) -> Result<(), JsValue>;

    #[wasm_bindgen(method, js_name = "run", catch)]
    fn run_with_params(this: &SqlJsDatabase, sql: &str, params: &JsValue) -> Result<(), JsValue>;

    #[wasm_bindgen(method, js_name = "exec", catch)]
    fn exec(this: &SqlJsDatabase, sql: &str) -> Result<js_sys::Array, JsValue>;

    // Allows exporting the binary data
    #[wasm_bindgen(method, js_name = "export")]
    fn export(this: &SqlJsDatabase) -> js_sys::Uint8Array;
}

// --- Main Database Struct ---
pub struct Database {
    db: SqlJsDatabase,
}

impl Database {
    pub async fn new() -> Result<Self, JsValue> {
        // 1. Configure sql.js
        // We need to tell it where to find the .wasm file.
        // We create a Closure that JS calls: (filename) -> full_url
        let config = js_sys::Object::new();
        let locate_file = Closure::wrap(Box::new(|filename: String| -> String {
            format!("https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.10.3/{}", filename)
        }) as Box<dyn Fn(String) -> String>);

        js_sys::Reflect::set(
            &config,
            &"locateFile".into(),
            locate_file.as_ref().unchecked_ref(),
        )?;

        // IMPORTANT: Prevent Rust from cleaning up the closure memory
        locate_file.forget();

        // 2. Initialize the Library
        // We look for 'initSqlJs' on the global window object
        let window = web_sys::window().expect("no global `window` exists");
        let init_fn = js_sys::Reflect::get(&window, &"initSqlJs".into())?;

        if init_fn.is_undefined() {
            return Err(JsValue::from_str("initSqlJs is not defined. Check your index.html script tag."));
        }

        let init_fn: js_sys::Function = init_fn.unchecked_into();
        let promise = init_fn.call1(&JsValue::NULL, &config)?;
        
        // Wait for the library to load
        let sql_js_val = wasm_bindgen_futures::JsFuture::from(js_sys::Promise::from(promise)).await?;

        // 3. Create the Database Instance
        let db_class = js_sys::Reflect::get(&sql_js_val, &"Database".into())?;
        let db_constructor: js_sys::Function = db_class.unchecked_into();
        let db_instance = js_sys::Reflect::construct(&db_constructor, &js_sys::Array::new())?;

        // Cast the generic JS object to our specific SqlJsDatabase type
        let db: SqlJsDatabase = db_instance.unchecked_into();

        let database = Database { db };
        database.init_tables();

        Ok(database)
    }

    fn init_tables(&self) {
        // We ignore errors here for simplicity, but in a real app you might log them
        let _ = self.db.run(
            "CREATE TABLE IF NOT EXISTS planned_sets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                exercise TEXT NOT NULL,
                set_number INTEGER NOT NULL,
                weight REAL NOT NULL,
                reps INTEGER NOT NULL,
                rest_seconds INTEGER NOT NULL
            )"
        );

        let _ = self.db.run(
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
            )"
        );
    }

    // --- Export Feature ---
    pub fn export(&self) -> js_sys::Uint8Array {
        self.db.export()
    }

    // --- Planned Sets Operations ---

    pub fn clear_planned_sets(&self) {
        if let Err(e) = self.db.run("DELETE FROM planned_sets") {
            web_sys::console::error_2(&"Clear Error:".into(), &e);
        }
    }

    pub fn insert_planned_set(&self, set: &PlannedSet) {
        let params = js_sys::Array::new();
        params.push(&JsValue::from_str(&set.exercise));
        params.push(&JsValue::from_f64(set.set_number as f64));
        params.push(&JsValue::from_f64(set.weight));
        params.push(&JsValue::from_f64(set.reps as f64));
        params.push(&JsValue::from_f64(set.rest_seconds as f64));

        if let Err(e) = self.db.run_with_params(
            "INSERT INTO planned_sets (exercise, set_number, weight, reps, rest_seconds) VALUES (?, ?, ?, ?, ?)",
            &params
        ) {
            web_sys::console::error_2(&"Insert Planned Error:".into(), &e);
        }
    }

    pub fn get_planned_sets(&self) -> Vec<PlannedSet> {
        match self.db.exec("SELECT id, exercise, set_number, weight, reps, rest_seconds FROM planned_sets ORDER BY id") {
            Ok(result) => self.parse_planned_sets(result),
            Err(e) => {
                web_sys::console::error_2(&"Select Planned Error:".into(), &e);
                Vec::new()
            }
        }
    }

    fn parse_planned_sets(&self, result: js_sys::Array) -> Vec<PlannedSet> {
        let mut sets = Vec::new();

        if result.length() == 0 {
            return sets;
        }

        // sql.js returns an array of objects: [{columns: [], values: [[...], [...]]}]
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

    // --- Completed Sets Operations ---

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

        if let Err(e) = self.db.run_with_params(
            "INSERT INTO completed_sets (exercise, set_number, weight, target_reps, completed_reps, start_time, end_time, rest_seconds) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            &params
        ) {
            web_sys::console::error_2(&"Insert Completed Error:".into(), &e);
        }
    }

    pub fn get_completed_sets(&self) -> Vec<CompletedSet> {
        match self.db.exec("SELECT id, exercise, set_number, weight, target_reps, completed_reps, start_time, end_time, rest_seconds FROM completed_sets ORDER BY id DESC") {
             Ok(result) => self.parse_completed_sets(result),
             Err(e) => {
                 web_sys::console::error_2(&"Select Completed Error:".into(), &e);
                 Vec::new()
             }
        }
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